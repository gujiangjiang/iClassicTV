//
//  AppDataManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AppDataManager.h"

@implementation AppDataManager

+ (instancetype)sharedManager {
    static AppDataManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (void)migrateLegacyDataIfNeeded {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *legacyM3U = [defs objectForKey:@"ios6_iptv_m3u"];
    if (legacyM3U) {
        NSString *sourceId = [[NSUUID UUID] UUIDString];
        NSDictionary *source = @{@"id": sourceId, @"name": @"默认直播源 (旧版)", @"content": legacyM3U, @"url": @""};
        [defs setObject:@[source] forKey:@"ios6_iptv_sources"];
        [defs setObject:sourceId forKey:@"ios6_iptv_active_source_id"];
        [defs removeObjectForKey:@"ios6_iptv_m3u"];
        [defs synchronize];
    }
}

- (void)clearAllSources {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs removeObjectForKey:@"ios6_iptv_sources"];
    [defs removeObjectForKey:@"ios6_iptv_active_source_id"];
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
}

- (void)clearAllPreferencesCache {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultsDict = [defs dictionaryRepresentation];
    for (NSString *key in [defaultsDict allKeys]) {
        if ([key hasPrefix:@"SourcePref_"]) {
            [defs removeObjectForKey:key];
        }
    }
    [defs synchronize];
}

@end