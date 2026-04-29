//
//  EPGManager+Update.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager+Update.h"
#import "EPGManager+Internal.h"
#import "EPGManager+Cache.h"
#import "EPGParser.h"
#import "ToastHelper.h"
#import "LanguageManager.h"
#import <zlib.h>
#import "NetworkManager.h" // [优化] 引入统一下载管理器

@implementation EPGManager (Update)

#pragma mark - GZIP Tools

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

#pragma mark - Timer Update

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
    
    // 静默更新交由全局进度条处理
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
    
    __block NSDate *maxEndTime = [[NSUserDefaults standardUserDefaults] objectForKey:kEPGMaxEndTimeKey];
    
    // [修复] 移除会导致主线程严重卡顿的全局遍历保底代码。由于缓存解析已转为异步，
    // 如果这里获取不到持久化的时间戳，直接返回 YES 触发一次后台静默更新，
    // 后台更新完毕后会自动重新计算并写入正确的时间戳，性能远优于在主线程进行百万级对象的遍历。
    if (!maxEndTime) {
        return YES;
    }
    
    NSDate *threshold = [[NSDate date] dateByAddingTimeInterval:7200];
    return ([maxEndTime compare:threshold] == NSOrderedAscending);
}

// [优化] 分离并完善应用启动时的自动更新逻辑，使得“打开软件自动更新”和“过期自动更新”不冲突
- (void)checkAndAutoUpdateEPG {
    if (!self.isEPGEnabled || self.isDynamicEPGSource) return;
    
    if (self.autoUpdateOnLaunch) {
        // 如果开启了“打开软件自动更新”：无论数据是否过期，只要启动了就直接刷新 EPG
        [self performSilentBackgroundUpdate];
    } else if (self.autoUpdateOnExpire && [self needsUpdate]) {
        // 如果开启了“过期自动更新”：当启动时判断到数据确已过期，也会触发刷新 EPG
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
    
    NSString *taskKey = @"epg_update_task";
    [ToastHelper showGlobalProgressHUDWithKey:taskKey title:LocalizedString(@"epg_status_preparing")];
    [ToastHelper updateGlobalProgressHUDWithKey:taskKey progress:0.05 text:LocalizedString(@"epg_status_preparing")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *mergedDict = [NSMutableDictionary dictionary];
        BOOL atLeastOneSuccess = NO;
        NSString *lastErrorMsg = nil;
        NSInteger currentUrlIndex = 0;
        
        for (NSString *rawUrl in urls) {
            @autoreleasepool {
                // [修复] 每次处理新的URL前，检查是否因为用户切换接口而被中止了更新任务
                if (!self.isUpdatingEPG) return;
                
                currentUrlIndex++;
                
                CGFloat prog = 0.05 + 0.6 * ((CGFloat)currentUrlIndex / (CGFloat)totalUrls);
                NSString *statusMsg = [NSString stringWithFormat:LocalizedString(@"epg_status_downloading_format"), (long)currentUrlIndex, (long)totalUrls];
                [ToastHelper updateGlobalProgressHUDWithKey:taskKey progress:prog text:statusMsg];
                
                NSString *urlStr = [rawUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (urlStr.length == 0) continue;
                
                NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                if (!url) continue;
                
                // [优化] 移除硬编码的 User-Agent 和冗余的原生请求代码，统一调用 NetworkManager 进行同步下载
                NSData *xmlData = [[NetworkManager sharedManager] downloadDataSyncFromURL:url];
                
                // [修复] 网络请求耗时较长，结束后再次检查更新是否已被中止，防止错误数据覆盖新接口缓存
                if (!self.isUpdatingEPG) return;
                
                if (!xmlData || xmlData.length == 0) {
                    lastErrorMsg = LocalizedString(@"epg_no_data");
                    continue;
                }
                
                if ([self isGzippedData:xmlData]) {
                    xmlData = [self gunzippedData:xmlData];
                }
                
                if (!xmlData || xmlData.length == 0) {
                    lastErrorMsg = LocalizedString(@"epg_unzip_failed");
                    continue;
                }
                
                [ToastHelper updateGlobalProgressHUDWithKey:taskKey progress:0.85 text:LocalizedString(@"epg_status_parsing")];
                
                NSDictionary *parsedDict = [EPGParser parseEPGXMLData:xmlData];
                
                if (parsedDict && parsedDict.count > 0) {
                    atLeastOneSuccess = YES;
                    [parsedDict enumerateKeysAndObjectsUsingBlock:^(id channelKey, id programs, BOOL *stop) {
                        if (![mergedDict objectForKey:channelKey]) {
                            [mergedDict setObject:programs forKey:channelKey];
                        }
                    }];
                } else {
                    lastErrorMsg = LocalizedString(@"epg_parse_empty");
                }
            }
        }
        
        // 最后提交缓存前做最后一次防误伤拦截
        if (!self.isUpdatingEPG) return;
        
        if (atLeastOneSuccess) {
            self.epgCacheDict = mergedDict;
            [self saveCacheToDisk:mergedDict];
            
            NSDate *globalMaxEndTime = [NSDate distantPast];
            for (NSArray *programs in [mergedDict allValues]) {
                EPGProgram *lastProgram = [programs lastObject];
                if (lastProgram && lastProgram.endTime) {
                    if ([lastProgram.endTime compare:globalMaxEndTime] == NSOrderedDescending) {
                        globalMaxEndTime = lastProgram.endTime;
                    }
                }
            }
            
            [[NSUserDefaults standardUserDefaults] setObject:globalMaxEndTime forKey:kEPGMaxEndTimeKey];
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kEPGLastUpdateTimeKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUpdatingEPG = NO;
                [ToastHelper dismissGlobalProgressHUDWithKey:taskKey text:LocalizedString(@"epg_update_complete") delay:3.0];
                if (completion) completion(YES, nil);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGDataDidUpdateNotification" object:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUpdatingEPG = NO;
                NSString *finalError = lastErrorMsg ?: LocalizedString(@"epg_all_sources_failed");
                [ToastHelper dismissGlobalProgressHUDWithKey:taskKey text:finalError delay:3.0];
                if (completion) completion(NO, finalError);
            });
        }
    });
}

@end