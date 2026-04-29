//
//  EPGManager+Cache.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager+Cache.h"
#import "EPGManager+Internal.h"
#import "EPGManager+Update.h" // [新增] 引入Update分类以回调启动更新检测

@implementation EPGManager (Cache)

- (NSString *)cacheFilePath {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cacheDir stringByAppendingPathComponent:@"ios6_iptv_epg_cache.dat"];
}

- (void)saveCacheToDisk:(NSDictionary *)dataDict {
    if (!dataDict) return;
    [NSKeyedArchiver archiveRootObject:dataDict toFile:[self cacheFilePath]];
}

- (void)loadCacheFromDisk {
    // [优化] 标记开始解析本地缓存
    self.isLoadingCache = YES;
    
    // [修复] EPG数据量极大，在主线程同步解档会导致冷启动黑屏卡顿长达十余秒。改为放入全局并发队列异步加载。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithFile:[self cacheFilePath]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // [优化] 标记缓存解析完成
            self.isLoadingCache = NO;
            
            if (dict) {
                self.epgCacheDict = dict;
                // [新增] 缓存异步加载完毕后，通知 UI 刷新最新的 EPG 数据
                [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGDataDidUpdateNotification" object:nil];
            }
            
            // [修复] 等待缓存真正加载完后，再进行开机更新过期检测，防止把未加载完的缓存当成空数据触发全量下载
            if ([self respondsToSelector:@selector(checkAndAutoUpdateEPG)]) {
                [self checkAndAutoUpdateEPG];
            }
        });
    });
}

- (void)clearEPGCache {
    self.epgCacheDict = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self cacheFilePath] error:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEPGLastUpdateTimeKey];
    // [优化] 清理缓存时，同步移除最大结束时间的持久化记录
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEPGMaxEndTimeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // [新增] 缓存被清理后，主动发送通知，让 UI 立即变回无数据状态
    [[NSNotificationCenter defaultCenter] postNotificationName:@"EPGDataDidUpdateNotification" object:nil];
}

@end