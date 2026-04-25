//
//  EPGManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"
#import "EPGParser.h"
#import "ToastHelper.h" // 引入ToastHelper用于静默提示
#import <zlib.h>        // 新增：引入 zlib 库用于支持 GZIP 解压

#define kEPGEnabledKey @"ios6_iptv_epg_enabled"
#define kEPGAutoUpdateKey @"ios6_iptv_epg_auto_update"
#define kEPGSourcesKey @"ios6_iptv_epg_sources_list"

@interface EPGManager ()
// 在内存中持有当前解析好的数据
@property (nonatomic, strong) NSDictionary *epgCacheDict;
@property (nonatomic, strong) NSMutableArray *internalSources;
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
        [self loadSourcesFromDisk];
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

- (BOOL)autoUpdateOnLaunch {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kEPGAutoUpdateKey];
}

- (void)setAutoUpdateOnLaunch:(BOOL)autoUpdateOnLaunch {
    [[NSUserDefaults standardUserDefaults] setBool:autoUpdateOnLaunch forKey:kEPGAutoUpdateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *)epgSources {
    return [self.internalSources copy];
}

- (NSString *)epgSourceURL {
    for (NSDictionary *source in self.internalSources) {
        if ([source[@"isActive"] boolValue]) {
            return source[@"url"];
        }
    }
    return @"";
}

#pragma mark - Sources Management

- (void)loadSourcesFromDisk {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:kEPGSourcesKey];
    if (saved && [saved isKindOfClass:[NSArray class]]) {
        self.internalSources = [NSMutableArray arrayWithArray:saved];
    } else {
        self.internalSources = [NSMutableArray array];
    }
}

- (void)saveSourcesToDisk {
    [[NSUserDefaults standardUserDefaults] setObject:self.internalSources forKey:kEPGSourcesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url {
    BOOL isFirst = (self.internalSources.count == 0);
    NSDictionary *newSource = @{ @"name": name ?: @"未知EPG",
                                 @"url": url ?: @"",
                                 @"isActive": @(isFirst) };
    [self.internalSources addObject:newSource];
    [self saveSourcesToDisk];
}

- (void)removeEPGSourceAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.internalSources.count) {
        BOOL wasActive = [self.internalSources[index][@"isActive"] boolValue];
        [self.internalSources removeObjectAtIndex:index];
        
        // 如果删除的是当前激活的源，并且还有剩余源，则自动激活第一个
        if (wasActive && self.internalSources.count > 0) {
            [self setActiveEPGSourceAtIndex:0];
        } else {
            [self saveSourcesToDisk];
        }
    }
}

- (void)renameEPGSourceAtIndex:(NSInteger)index withName:(NSString *)name url:(NSString *)url {
    if (index >= 0 && index < self.internalSources.count) {
        NSMutableDictionary *dict = [self.internalSources[index] mutableCopy];
        dict[@"name"] = name ?: dict[@"name"];
        dict[@"url"] = url ?: dict[@"url"];
        self.internalSources[index] = [dict copy];
        [self saveSourcesToDisk];
    }
}

- (void)setActiveEPGSourceAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.internalSources.count) {
        for (NSInteger i = 0; i < self.internalSources.count; i++) {
            NSMutableDictionary *dict = [self.internalSources[i] mutableCopy];
            dict[@"isActive"] = @(i == index);
            self.internalSources[i] = [dict copy];
        }
        [self saveSourcesToDisk];
    }
}

#pragma mark - GZIP 解压支持 (新增)

// 判断数据是否为 GZIP 格式 (通过判断魔数 1F 8B)
- (BOOL)isGzippedData:(NSData *)data {
    if (data.length < 2) return NO;
    const UInt8 *bytes = (const UInt8 *)data.bytes;
    return (bytes[0] == 0x1f && bytes[1] == 0x8b);
}

// 解压 GZIP 数据为普通的 XML NSData
- (NSData *)gunzippedData:(NSData *)data {
    if (data.length == 0) return data;
    
    unsigned full_length = (unsigned)[data length];
    unsigned half_length = (unsigned)[data length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength:full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[data bytes];
    strm.avail_in = (uInt)[data length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    // 15 + 32 用于自动检测 zlib 还是 gzip 头部
    if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
    
    while (!done) {
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy:half_length];
        }
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([decompressed length] - strm.total_out);
        
        status = inflate(&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
            done = YES;
        } else if (status != Z_OK) {
            break;
        }
    }
    
    if (inflateEnd(&strm) != Z_OK) return nil;
    
    if (done) {
        [decompressed setLength:strm.total_out];
        return [NSData dataWithData:decompressed];
    } else {
        return nil;
    }
}

#pragma mark - Auto Update Logic

// 检查是否需要更新（判断缓存中最晚的节目结束时间是否小于明天凌晨 0 点）
- (BOOL)needsUpdate {
    if (!self.epgCacheDict || self.epgCacheDict.count == 0) return YES;
    
    NSDate *maxEndTime = [NSDate distantPast];
    for (NSArray *programs in self.epgCacheDict.allValues) {
        for (EPGProgram *p in programs) {
            if ([p.endTime compare:maxEndTime] == NSOrderedDescending) {
                maxEndTime = p.endTime;
            }
        }
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:[NSDate date]];
    components.day += 1; // 明天
    NSDate *tomorrowMidnight = [calendar dateFromComponents:components];
    
    // 如果最大结束时间在明天凌晨之前，说明没有明日的有效缓存，需要更新
    return ([maxEndTime compare:tomorrowMidnight] == NSOrderedAscending);
}

- (void)checkAndAutoUpdateEPG {
    if (!self.isEPGEnabled || !self.autoUpdateOnLaunch) return;
    
    if ([self needsUpdate]) {
        [ToastHelper showToastWithMessage:@"EPG 数据静默更新中..."];
        [self fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
            if (success) {
                [ToastHelper showToastWithMessage:@"EPG 数据更新完成"];
            } else {
                [ToastHelper showToastWithMessage:[NSString stringWithFormat:@"EPG 更新失败: %@", errorMsg]];
            }
        }];
    }
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
        // 下载 XML (或 XML.GZ) 数据
        NSError *error = nil;
        NSData *xmlData = [NSData dataWithContentsOfURL:url options:0 error:&error];
        
        if (error || !xmlData || xmlData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, @"DOWNLOAD_FAILED");
            });
            return;
        }
        
        // 新增：判断是否为 GZIP 压缩数据，如果是则在后台线程进行解压
        if ([self isGzippedData:xmlData]) {
            xmlData = [self gunzippedData:xmlData];
            if (!xmlData || xmlData.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(NO, @"DECOMPRESS_FAILED");
                });
                return;
            }
        }
        
        // 开始解析 (解压后就是标准的 XML 数据)
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