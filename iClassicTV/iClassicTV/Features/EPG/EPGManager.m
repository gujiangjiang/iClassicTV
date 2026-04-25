//
//  EPGManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"
#import "EPGParser.h"

#define kEPGEnabledKey @"ios6_iptv_epg_enabled"
#define kEPGSourceURLKey @"ios6_iptv_epg_source_url"

@interface EPGManager ()
// 在内存中持有当前解析好的数据
@property (nonatomic, strong) NSDictionary *epgCacheDict;
@end

@implementation EPGManager

+ (instancetype)sharedManager {
    static EPGManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadCacheFromDisk];
    }
    return self;
}

#pragma mark - Properties

- (BOOL)isEPGEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kEPGEnabledKey];
}

- (void)setIsEPGEnabled:(BOOL)isEPGEnabled {
    [[NSUserDefaults standardUserDefaults] setBool:isEPGEnabled forKey:kEPGEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)epgSourceURL {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kEPGSourceURLKey] ?: @"";
}

- (void)setEpgSourceURL:(NSString *)epgSourceURL {
    [[NSUserDefaults standardUserDefaults] setObject:epgSourceURL forKey:kEPGSourceURLKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Actions

- (void)fetchAndParseEPGDataWithCompletion:(void(^)(BOOL success, NSString *errorMsg))completion {
    if (self.epgSourceURL.length == 0) {
        if (completion) completion(NO, @"URL_EMPTY");
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[self.epgSourceURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if (!url) {
        if (completion) completion(NO, @"URL_INVALID");
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 下载 XML 数据
        NSError *error = nil;
        NSData *xmlData = [NSData dataWithContentsOfURL:url options:0 error:&error];
        
        if (error || !xmlData || xmlData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, @"DOWNLOAD_FAILED");
            });
            return;
        }
        
        // 开始解析
        NSDictionary *parsedDict = [EPGParser parseEPGXMLData:xmlData];
        
        if (parsedDict && parsedDict.count > 0) {
            // 保存至内存和磁盘
            self.epgCacheDict = parsedDict;
            [self saveCacheToDisk:parsedDict];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(YES, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, @"PARSE_FAILED");
            });
        }
    });
}

#pragma mark - Query

// 查询时的归一化逻辑，必须与解析时的规则完全一致，保证能模糊命中
- (NSString *)normalizeQueryName:(NSString *)name {
    if (!name || name.length == 0) return @"";
    NSMutableString *normalized = [NSMutableString stringWithString:[name lowercaseString]];
    [normalized replaceOccurrencesOfString:@"-" withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    [normalized replaceOccurrencesOfString:@"_" withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    [normalized replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    
    // 这里额外处理后缀降级：如果 M3U 是 "CCTV1 4K" (清洗后为 cctv14k)，
    // 但 EPG 只有 "CCTV1" (清洗后为 cctv1)，在严格模式下配对不上。
    // 在后续扩展中，我们可以在这里将末尾的 4k/8k 剔除以实现自动降级匹配。
    
    return [NSString stringWithString:normalized];
}

- (NSArray *)programsForChannelName:(NSString *)channelName {
    if (!self.isEPGEnabled || !self.epgCacheDict || channelName.length == 0) return nil;
    
    NSString *normalizedName = [self normalizeQueryName:channelName];
    NSArray *programs = self.epgCacheDict[normalizedName];
    
    // 如果没有直接命中，尝试剥离常见的高清后缀进行降级匹配
    // 修复：NSArray 获取元素数量应使用 count 属性
    if (!programs || programs.count == 0) {
        NSString *fallbackName = [normalizedName stringByReplacingOccurrencesOfString:@"4k" withString:@""];
        fallbackName = [fallbackName stringByReplacingOccurrencesOfString:@"8k" withString:@""];
        fallbackName = [fallbackName stringByReplacingOccurrencesOfString:@"hd" withString:@""];
        fallbackName = [fallbackName stringByReplacingOccurrencesOfString:@"fhd" withString:@""];
        if (![fallbackName isEqualToString:normalizedName]) {
            programs = self.epgCacheDict[fallbackName];
        }
    }
    
    return programs;
}

- (EPGProgram *)currentProgramForChannelName:(NSString *)channelName {
    NSArray *programs = [self programsForChannelName:channelName];
    if (!programs || programs.count == 0) return nil;
    
    NSDate *now = [NSDate date];
    for (EPGProgram *program in programs) {
        // 判断当前时间是否在节目的 start 和 end 之间
        if ([now compare:program.startTime] != NSOrderedAscending &&
            [now compare:program.endTime] != NSOrderedDescending) {
            return program;
        }
    }
    return nil;
}

#pragma mark - Disk Cache

- (NSString *)cacheFilePath {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cacheDir stringByAppendingPathComponent:@"ios6_iptv_epg_cache.dat"];
}

- (void)saveCacheToDisk:(NSDictionary *)dataDict {
    if (!dataDict) return;
    [NSKeyedArchiver archiveRootObject:dataDict toFile:[self cacheFilePath]];
}

- (void)loadCacheFromDisk {
    NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithFile:[self cacheFilePath]];
    if (dict) {
        self.epgCacheDict = dict;
    }
}

- (void)clearEPGCache {
    self.epgCacheDict = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self cacheFilePath] error:nil];
}

@end