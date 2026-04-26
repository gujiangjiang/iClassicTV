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
    
    // [修复] 补充 __block 修饰符，使得在 Block 内部可以正常修改这个变量
    __block NSDate *maxEndTime = [[NSUserDefaults standardUserDefaults] objectForKey:kEPGMaxEndTimeKey];
    
    // 如果因某种原因缓存不存在，做一次全量扫描保底，并重新写入缓存
    if (!maxEndTime) {
        maxEndTime = [NSDate distantPast];
        [self.epgCacheDict enumerateKeysAndObjectsUsingBlock:^(id key, NSArray *programs, BOOL *stop) {
            EPGProgram *lastProgram = [programs lastObject]; // 节目通常按时间排序，只需取最后一个判断即可
            if (lastProgram && lastProgram.endTime) {
                if ([lastProgram.endTime compare:maxEndTime] == NSOrderedDescending) {
                    maxEndTime = lastProgram.endTime;
                }
            } else {
                for (EPGProgram *p in programs) {
                    if (p.endTime && [p.endTime compare:maxEndTime] == NSOrderedDescending) {
                        maxEndTime = p.endTime;
                    }
                }
            }
        }];
        [[NSUserDefaults standardUserDefaults] setObject:maxEndTime forKey:kEPGMaxEndTimeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
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
    
    [ToastHelper showGlobalProgressHUDWithTitle:LocalizedString(@"epg_status_preparing")];
    [ToastHelper updateGlobalProgressHUD:0.05 text:LocalizedString(@"epg_status_preparing")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *mergedDict = [NSMutableDictionary dictionary];
        BOOL atLeastOneSuccess = NO;
        NSString *lastErrorMsg = nil;
        NSInteger currentUrlIndex = 0;
        
        for (NSString *rawUrl in urls) {
            @autoreleasepool {
                currentUrlIndex++;
                
                CGFloat prog = 0.05 + 0.6 * ((CGFloat)currentUrlIndex / (CGFloat)totalUrls);
                NSString *statusMsg = [NSString stringWithFormat:LocalizedString(@"epg_status_downloading_format"), (long)currentUrlIndex, (long)totalUrls];
                [ToastHelper updateGlobalProgressHUD:prog text:statusMsg];
                
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
                
                [ToastHelper updateGlobalProgressHUD:0.85 text:LocalizedString(@"epg_status_parsing")];
                
                NSDictionary *parsedDict = [EPGParser parseEPGXMLData:xmlData];
                
                // [优化] 摒弃 for-in 循环，使用底层的 Block 枚举方式合并字典，在庞大数据集下效率更高
                if (parsedDict && parsedDict.count > 0) {
                    atLeastOneSuccess = YES;
                    [parsedDict enumerateKeysAndObjectsUsingBlock:^(id channelKey, id programs, BOOL *stop) {
                        if (!mergedDict[channelKey]) {
                            mergedDict[channelKey] = programs;
                        }
                    }];
                } else {
                    lastErrorMsg = @"XML parse resulted in empty data";
                }
            }
        }
        
        if (atLeastOneSuccess) {
            self.epgCacheDict = mergedDict;
            [self saveCacheToDisk:mergedDict];
            
            // [优化] 在此异步线程一并计算出全局的最大结束时间，并存入 NSUserDefaults，彻底解放 UI 线程
            NSDate *globalMaxEndTime = [NSDate distantPast];
            for (NSArray *programs in mergedDict.allValues) {
                EPGProgram *lastProgram = [programs lastObject]; // 节目通常按时间排序，只需取最后一个判断即可
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
                [ToastHelper dismissGlobalProgressHUDWithText:@"EPG 更新完成" delay:3.0];
                if (completion) completion(YES, nil);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGDataDidUpdateNotification" object:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUpdatingEPG = NO;
                NSString *finalError = lastErrorMsg ?: LocalizedString(@"epg_all_sources_failed");
                // [修复] 将失败后的悬浮窗显示时间从 30 秒改为 3 秒，避免长时间遮挡
                [ToastHelper dismissGlobalProgressHUDWithText:finalError delay:3.0];
                if (completion) completion(NO, finalError);
            });
        }
    });
}

@end