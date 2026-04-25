//
//  EPGManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"
#import "EPGParser.h"
#import "ToastHelper.h"
#import "LanguageManager.h"
#import <zlib.h>

#define kEPGEnabledKey @"ios6_iptv_epg_enabled"
#define kEPGAutoUpdateKey @"ios6_iptv_epg_auto_update"
#define kEPGSourcesKey @"ios6_iptv_epg_sources_list"
#define kEPGTimeZoneNameKey @"ios6_iptv_epg_timezone_name"
#define kEPGAutoScrollTimeoutKey @"ios6_iptv_epg_autoscroll_timeout"

#define kEPGAutoUpdateExpireKey @"ios6_iptv_epg_auto_update_expire"
#define kEPGScheduledUpdateTimeKey @"ios6_iptv_epg_scheduled_update_time"
#define kEPGLastUpdateTimeKey @"ios6_iptv_epg_last_update_time"

@interface EPGManager ()
@property (nonatomic, strong) NSDictionary *epgCacheDict;
@property (nonatomic, strong) NSMutableArray *internalSources;

@property (nonatomic, strong) NSTimer *autoUpdateTimer;
@property (nonatomic, assign) BOOL hasTriggeredScheduledUpdateThisMinute;
@property (nonatomic, assign) BOOL isUpdatingEPG;
@property (nonatomic, strong) NSDate *lastFailedUpdateTime;

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
        [self startAutoUpdateTimer];
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

- (BOOL)autoUpdateOnExpire {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kEPGAutoUpdateExpireKey];
}

- (void)setAutoUpdateOnExpire:(BOOL)autoUpdateOnExpire {
    [[NSUserDefaults standardUserDefaults] setBool:autoUpdateOnExpire forKey:kEPGAutoUpdateExpireKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)scheduledUpdateTimeString {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kEPGScheduledUpdateTimeKey];
}

- (void)setScheduledUpdateTimeString:(NSString *)scheduledUpdateTimeString {
    if (!scheduledUpdateTimeString || scheduledUpdateTimeString.length == 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEPGScheduledUpdateTimeKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:scheduledUpdateTimeString forKey:kEPGScheduledUpdateTimeKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)lastEPGUpdateTime {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kEPGLastUpdateTimeKey];
}

- (NSTimeZone *)epgTimeZone {
    NSString *tzName = [[NSUserDefaults standardUserDefaults] stringForKey:kEPGTimeZoneNameKey];
    if (tzName && tzName.length > 0) {
        if ([tzName isEqualToString:@"System"]) {
            return [NSTimeZone localTimeZone];
        }
        NSTimeZone *tz = [NSTimeZone timeZoneWithName:tzName];
        if (tz) return tz;
    }
    return [NSTimeZone localTimeZone];
}

- (void)setEpgTimeZone:(NSTimeZone *)epgTimeZone {
    if (!epgTimeZone) {
        [[NSUserDefaults standardUserDefaults] setObject:@"System" forKey:kEPGTimeZoneNameKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:epgTimeZone.name forKey:kEPGTimeZoneNameKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSInteger)autoScrollTimeout {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kEPGAutoScrollTimeoutKey] == nil) {
        return 10;
    }
    return [[NSUserDefaults standardUserDefaults] integerForKey:kEPGAutoScrollTimeoutKey];
}

- (void)setAutoScrollTimeout:(NSInteger)autoScrollTimeout {
    [[NSUserDefaults standardUserDefaults] setInteger:autoScrollTimeout forKey:kEPGAutoScrollTimeoutKey];
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

- (NSString *)epgSourceType {
    for (NSDictionary *source in self.internalSources) {
        if ([source[@"isActive"] boolValue]) {
            NSString *type = source[@"type"];
            return (type && type.length > 0) ? type : @"xml";
        }
    }
    return @"xml";
}

- (BOOL)isDynamicEPGSource {
    NSString *type = [self epgSourceType];
    return [type isEqualToString:@"diyp"] || [type isEqualToString:@"epginfo"];
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

- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url type:(NSString *)type {
    [self addEPGSourceWithName:name url:url type:type linkedM3UId:nil];
}

- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url type:(NSString *)type linkedM3UId:(NSString *)linkedM3UId {
    NSMutableDictionary *newSource = [@{
                                        @"name": name ?: LocalizedString(@"unnamed_source"),
                                        @"url": url ?: @"",
                                        @"type": type ?: @"xml",
                                        @"isActive": @(NO)
                                        } mutableCopy];
    
    if (linkedM3UId) {
        newSource[@"linkedM3UId"] = linkedM3UId;
        for (NSInteger i = 0; i < self.internalSources.count; i++) {
            if ([self.internalSources[i][@"linkedM3UId"] isEqualToString:linkedM3UId]) {
                BOOL wasActive = [self.internalSources[i][@"isActive"] boolValue];
                newSource[@"isActive"] = @(wasActive);
                self.internalSources[i] = newSource;
                [self saveSourcesToDisk];
                return;
            }
        }
    }
    
    BOOL isFirst = (self.internalSources.count == 0);
    newSource[@"isActive"] = @(isFirst);
    [self.internalSources addObject:newSource];
    [self saveSourcesToDisk];
}

- (void)removeEPGSourceAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.internalSources.count) {
        BOOL wasActive = [self.internalSources[index][@"isActive"] boolValue];
        [self.internalSources removeObjectAtIndex:index];
        
        if (wasActive && self.internalSources.count > 0) {
            [self setActiveEPGSourceAtIndex:0];
        } else {
            [self saveSourcesToDisk];
        }
    }
}

- (void)removeEPGSourceByLinkedM3UId:(NSString *)m3uId {
    if (!m3uId) return;
    NSInteger targetIndex = -1;
    for (NSInteger i = 0; i < self.internalSources.count; i++) {
        if ([self.internalSources[i][@"linkedM3UId"] isEqualToString:m3uId]) {
            targetIndex = i;
            break;
        }
    }
    if (targetIndex != -1) {
        [self removeEPGSourceAtIndex:targetIndex];
    }
}

- (void)updateLinkedEPGSourceName:(NSString *)name forM3UId:(NSString *)m3uId {
    if (!m3uId || !name) return;
    for (NSInteger i = 0; i < self.internalSources.count; i++) {
        if ([self.internalSources[i][@"linkedM3UId"] isEqualToString:m3uId]) {
            NSMutableDictionary *dict = [self.internalSources[i] mutableCopy];
            dict[@"name"] = name;
            self.internalSources[i] = [dict copy];
            [self saveSourcesToDisk];
            break;
        }
    }
}

- (void)removeAllLinkedEPGSources {
    NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
    BOOL removedActive = NO;
    for (NSInteger i = 0; i < self.internalSources.count; i++) {
        if (self.internalSources[i][@"linkedM3UId"]) {
            [indexesToRemove addIndex:i];
            if ([self.internalSources[i][@"isActive"] boolValue]) {
                removedActive = YES;
            }
        }
    }
    [self.internalSources removeObjectsAtIndexes:indexesToRemove];
    if (removedActive && self.internalSources.count > 0) {
        [self setActiveEPGSourceAtIndex:0];
    } else {
        [self saveSourcesToDisk];
    }
}

- (void)renameEPGSourceAtIndex:(NSInteger)index withName:(NSString *)name url:(NSString *)url type:(NSString *)type {
    if (index >= 0 && index < self.internalSources.count) {
        NSMutableDictionary *dict = [self.internalSources[index] mutableCopy];
        dict[@"name"] = name ?: dict[@"name"];
        dict[@"url"] = url ?: dict[@"url"];
        dict[@"type"] = type ?: dict[@"type"];
        self.internalSources[index] = [dict copy];
        [self saveSourcesToDisk];
    }
}

- (void)setActiveEPGSourceAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.internalSources.count) {
        BOOL changed = NO;
        for (NSInteger i = 0; i < self.internalSources.count; i++) {
            BOOL isActive = [self.internalSources[i][@"isActive"] boolValue];
            if (i == index && !isActive) changed = YES;
            if (i != index && isActive) changed = YES;
            
            NSMutableDictionary *dict = [self.internalSources[i] mutableCopy];
            dict[@"isActive"] = @(i == index);
            self.internalSources[i] = [dict copy];
        }
        [self saveSourcesToDisk];
        if (changed) {
            [self clearEPGCache];
        }
    }
}

#pragma mark - GZIP

- (BOOL)isGzippedData:(NSData *)data {
    if (data.length < 2) return NO;
    const UInt8 *bytes = (const UInt8 *)data.bytes;
    return (bytes[0] == 0x1f && bytes[1] == 0x8b);
}

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
    if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
    
    while (!done) {
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy:half_length];
        }
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([decompressed length] - strm.total_out);
        status = inflate(&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) { done = YES; }
        else if (status != Z_OK) { break; }
    }
    if (inflateEnd(&strm) != Z_OK) return nil;
    if (done) {
        [decompressed setLength:strm.total_out];
        return [NSData dataWithData:decompressed];
    } else {
        return nil;
    }
}

#pragma mark - Auto Update / Background Refresh Timer

- (void)startAutoUpdateTimer {
    if (!self.autoUpdateTimer) {
        self.autoUpdateTimer = [NSTimer timerWithTimeInterval:30.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.autoUpdateTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)timerTick {
    if (!self.isEPGEnabled || self.isDynamicEPGSource || self.isUpdatingEPG) return;
    
    if (self.scheduledUpdateTimeString.length > 0) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setTimeZone:[NSTimeZone localTimeZone]];
        [df setDateFormat:@"HH:mm"];
        NSString *nowStr = [df stringFromDate:[NSDate date]];
        
        if ([nowStr isEqualToString:self.scheduledUpdateTimeString]) {
            if (!self.hasTriggeredScheduledUpdateThisMinute) {
                self.hasTriggeredScheduledUpdateThisMinute = YES;
                [self performSilentBackgroundUpdate];
                return;
            }
        } else {
            self.hasTriggeredScheduledUpdateThisMinute = NO;
        }
    }
    
    if (self.autoUpdateOnExpire) {
        if ([self needsUpdate]) {
            if (self.lastFailedUpdateTime && [[NSDate date] timeIntervalSinceDate:self.lastFailedUpdateTime] < 3600) {
                return;
            }
            [self performSilentBackgroundUpdate];
        }
    }
}

- (void)performSilentBackgroundUpdate {
    if (self.isUpdatingEPG) return;
    
    // 静默更新不再直接弹 Toast，而是交给进度条逻辑
    [self fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        if (!success) {
            self.lastFailedUpdateTime = [NSDate date];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *safeMsg = errorMsg ?: LocalizedString(@"unknown_error");
                [ToastHelper showToastWithMessage:[NSString stringWithFormat:LocalizedString(@"epg_update_failed_msg"), safeMsg]];
            });
        } else {
            self.lastFailedUpdateTime = nil;
        }
    }];
}

- (BOOL)needsUpdate {
    if (!self.epgCacheDict || self.epgCacheDict.count == 0) return YES;
    
    NSDate *lastSuccess = [self lastEPGUpdateTime];
    if (lastSuccess && [[NSDate date] timeIntervalSinceDate:lastSuccess] < 14400) {
        return NO;
    }
    
    NSDate *maxEndTime = [NSDate distantPast];
    for (NSArray *programs in self.epgCacheDict.allValues) {
        for (EPGProgram *p in programs) {
            if ([p.endTime compare:maxEndTime] == NSOrderedDescending) {
                maxEndTime = p.endTime;
            }
        }
    }
    
    NSDate *threshold = [[NSDate date] dateByAddingTimeInterval:7200];
    return ([maxEndTime compare:threshold] == NSOrderedAscending);
}

- (void)checkAndAutoUpdateEPG {
    if (!self.isEPGEnabled || !self.autoUpdateOnLaunch || self.isDynamicEPGSource) return;
    if ([self needsUpdate]) {
        [self performSilentBackgroundUpdate];
    }
}

#pragma mark - Actions (XML Download & Merge)

- (void)fetchAndParseEPGDataWithCompletion:(void(^)(BOOL success, NSString *errorMsg))completion {
    if (self.isUpdatingEPG) {
        if (completion) completion(NO, LocalizedString(@"epg_is_updating"));
        return;
    }
    
    if (self.epgSourceURL.length == 0) {
        if (completion) completion(NO, @"URL_EMPTY");
        return;
    }
    
    self.isUpdatingEPG = YES;
    NSArray *urls = [self.epgSourceURL componentsSeparatedByString:@","];
    NSInteger totalUrls = urls.count;
    
    // [新增] 广播：准备开始
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGUpdateProgressNotification" object:nil userInfo:@{@"progress": @(0.05), @"status": LocalizedString(@"epg_status_preparing")}];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *mergedDict = [NSMutableDictionary dictionary];
        BOOL atLeastOneSuccess = NO;
        NSString *lastErrorMsg = nil;
        NSInteger currentUrlIndex = 0;
        
        for (NSString *rawUrl in urls) {
            @autoreleasepool {
                currentUrlIndex++;
                
                // [新增] 广播：正在下载第 N 个源
                dispatch_async(dispatch_get_main_queue(), ^{
                    CGFloat prog = 0.05 + 0.6 * ((CGFloat)currentUrlIndex / (CGFloat)totalUrls);
                    NSString *statusMsg = [NSString stringWithFormat:LocalizedString(@"epg_status_downloading_format"), (long)currentUrlIndex, (long)totalUrls];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGUpdateProgressNotification" object:nil userInfo:@{@"progress": @(prog), @"status": statusMsg}];
                });
                
                NSString *urlStr = [rawUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (urlStr.length == 0) continue;
                
                NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                if (!url) continue;
                
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
                [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Mobile/10B329 iClassicTV" forHTTPHeaderField:@"User-Agent"];
                
                NSURLResponse *response = nil;
                NSError *error = nil;
                NSData *xmlData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                
                if (error || !xmlData || xmlData.length == 0) {
                    lastErrorMsg = error ? error.localizedDescription : @"No Data returned";
                    continue;
                }
                
                if ([self isGzippedData:xmlData]) {
                    xmlData = [self gunzippedData:xmlData];
                }
                
                if (!xmlData || xmlData.length == 0) {
                    lastErrorMsg = @"Gzip decompression failed";
                    continue;
                }
                
                // [新增] 广播：数据较大，进入解析阶段
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGUpdateProgressNotification" object:nil userInfo:@{@"progress": @(0.85), @"status": LocalizedString(@"epg_status_parsing")}];
                });
                
                NSDictionary *parsedDict = [EPGParser parseEPGXMLData:xmlData];
                if (parsedDict && parsedDict.count > 0) {
                    atLeastOneSuccess = YES;
                    for (NSString *channelKey in parsedDict) {
                        if (!mergedDict[channelKey]) {
                            mergedDict[channelKey] = parsedDict[channelKey];
                        }
                    }
                } else {
                    lastErrorMsg = @"XML parse resulted in empty data";
                }
            }
        }
        
        if (atLeastOneSuccess) {
            self.epgCacheDict = mergedDict;
            [self saveCacheToDisk:mergedDict];
            
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kEPGLastUpdateTimeKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUpdatingEPG = NO;
                // [新增] 广播：完成状态
                [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGUpdateProgressNotification" object:nil userInfo:@{@"progress": @(1.0), @"status": LocalizedString(@"epg_manager_title")}];
                if (completion) completion(YES, nil);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGDataDidUpdateNotification" object:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUpdatingEPG = NO;
                // [新增] 广播：失败状态直接隐藏
                [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGUpdateProgressNotification" object:nil userInfo:@{@"progress": @(1.0), @"status": LocalizedString(@"epg_manager_title")}];
                NSString *finalError = lastErrorMsg ?: LocalizedString(@"epg_all_sources_failed");
                if (completion) completion(NO, finalError);
            });
        }
    });
}

#pragma mark - Query (XML)

- (NSString *)normalizeQueryName:(NSString *)name {
    if (!name || name.length == 0) return @"";
    NSMutableString *normalized = [NSMutableString stringWithString:[name lowercaseString]];
    [normalized replaceOccurrencesOfString:@"-" withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    [normalized replaceOccurrencesOfString:@"_" withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    [normalized replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    return [NSString stringWithString:normalized];
}

- (NSArray *)programsForChannelName:(NSString *)channelName {
    if (!self.isEPGEnabled || self.isDynamicEPGSource || !self.epgCacheDict || channelName.length == 0) return nil;
    
    NSString *normalizedName = [self normalizeQueryName:channelName];
    NSArray *programs = self.epgCacheDict[normalizedName];
    
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
        if ([now compare:program.startTime] != NSOrderedAscending &&
            [now compare:program.endTime] != NSOrderedDescending) {
            return program;
        }
    }
    return nil;
}

#pragma mark - Disk Cache (XML)

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
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEPGLastUpdateTimeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Dynamic Query

- (void)fetchDynamicProgramsForChannelName:(NSString *)channelName date:(NSDate *)date completion:(void(^)(NSArray *programs))completion {
    if (!channelName || channelName.length == 0 || !date) {
        if (completion) completion(nil);
        return;
    }
    
    NSString *urlStr = self.epgSourceURL;
    if (urlStr.length == 0) {
        if (completion) completion(nil);
        return;
    }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setTimeZone:self.epgTimeZone];
    [df setDateFormat:@"yyyy-MM-dd"];
    NSString *dateStr = [df stringFromDate:date];
    NSString *encodedChannel = [channelName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSString *finalURLStr;
    if ([urlStr rangeOfString:@"?"].location != NSNotFound) {
        finalURLStr = [NSString stringWithFormat:@"%@&ch=%@&date=%@", urlStr, encodedChannel, dateStr];
    } else {
        finalURLStr = [NSString stringWithFormat:@"%@?ch=%@&date=%@", urlStr, encodedChannel, dateStr];
    }
    
    NSURL *url = [NSURL URLWithString:finalURLStr];
    if (!url) {
        if (completion) completion(nil);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Mobile/10B329 iClassicTV" forHTTPHeaderField:@"User-Agent"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil); });
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error || !json || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil); });
            return;
        }
        
        NSArray *epgData = json[@"epg_data"];
        if (!epgData || ![epgData isKindOfClass:[NSArray class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil); });
            return;
        }
        
        NSMutableArray *programs = [NSMutableArray array];
        
        NSTimeZone *cstZone = self.epgTimeZone;
        NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
        [timeFormatter setTimeZone:cstZone];
        [timeFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
        
        NSDateFormatter *timeFormatterWithSeconds = [[NSDateFormatter alloc] init];
        [timeFormatterWithSeconds setTimeZone:cstZone];
        [timeFormatterWithSeconds setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        for (NSDictionary *item in epgData) {
            NSString *start = item[@"start"];
            NSString *end = item[@"end"];
            NSString *title = item[@"title"];
            
            if (!start || !title) continue;
            
            NSString *startFullStr = [NSString stringWithFormat:@"%@ %@", dateStr, start];
            NSDate *startDate = [start componentsSeparatedByString:@":"].count == 3 ? [timeFormatterWithSeconds dateFromString:startFullStr] : [timeFormatter dateFromString:startFullStr];
            
            NSDate *endDate = nil;
            if (end) {
                NSString *endFullStr = [NSString stringWithFormat:@"%@ %@", dateStr, end];
                endDate = [end componentsSeparatedByString:@":"].count == 3 ? [timeFormatterWithSeconds dateFromString:endFullStr] : [timeFormatter dateFromString:endFullStr];
            }
            
            if (startDate && title) {
                EPGProgram *p = [[EPGProgram alloc] init];
                p.title = title;
                p.startTime = startDate;
                if (endDate) {
                    if ([endDate compare:startDate] == NSOrderedAscending) {
                        endDate = [endDate dateByAddingTimeInterval:86400];
                    }
                    p.endTime = endDate;
                }
                [programs addObject:p];
            }
        }
        
        for (NSInteger i = 0; i < programs.count; i++) {
            EPGProgram *p = programs[i];
            if (!p.endTime) {
                if (i < programs.count - 1) {
                    EPGProgram *nextP = programs[i+1];
                    p.endTime = nextP.startTime;
                } else {
                    p.endTime = [p.startTime dateByAddingTimeInterval:1800];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(programs);
        });
    });
}

@end