//
//  EPGManager+Cache.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager+Cache.h"
#import "EPGManager+Internal.h"

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
    NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithFile:[self cacheFilePath]];
    if (dict) {
        self.epgCacheDict = dict;
    }
}

- (void)clearEPGCache {
    self.epgCacheDict = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self cacheFilePath] error:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEPGLastUpdateTimeKey];
    // [优化] 清理缓存时，同步移除最大结束时间的持久化记录
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEPGMaxEndTimeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end