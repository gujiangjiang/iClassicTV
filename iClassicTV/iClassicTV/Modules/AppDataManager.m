//
//  AppDataManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AppDataManager.h"
#import "LanguageManager.h" // 新增多语言

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
        // 替换名称
        NSDictionary *source = @{@"id": sourceId, @"name": LocalizedString(@"default_source_legacy"), @"content": legacyM3U, @"url": @""};
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

- (void)clearAllChannelIcons {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cacheDir error:nil];
    for (NSString *file in files) {
        NSString *path = [cacheDir stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

- (void)clearAllGeneralCache {
    NSString *tempDir = NSTemporaryDirectory();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempDir error:nil];
    for (NSString *file in files) {
        NSString *path = [tempDir stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)restoreAllSettings {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs removeObjectForKey:@"kUAManagerListKey"];
    [defs removeObjectForKey:@"kUAManagerSelectedIndexKey"];
    [defs removeObjectForKey:@"PlayerOrientationPref"];
    [defs removeObjectForKey:@"PlayerTypePref"];
    
    // [优化] 清理新增的播放器专属配置项
    [defs removeObjectForKey:@"ShowEPGInFullscreenPref"];
    [defs removeObjectForKey:@"ShowTimeInFullscreenPref"];
    
    [defs synchronize];
}

- (NSMutableArray *)getAllSources {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"ios6_iptv_sources"] mutableCopy] ?: [NSMutableArray array];
}

- (NSDictionary *)getActiveSourceInfo {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *sources = [defs objectForKey:@"ios6_iptv_sources"];
    NSString *activeId = [defs objectForKey:@"ios6_iptv_active_source_id"];
    
    for (NSDictionary *dict in sources) {
        if ([dict[@"id"] isEqualToString:activeId]) {
            return dict;
        }
    }
    return @{@"content": @"", @"name": LocalizedString(@"channel_list")};
}

- (void)addSourceWithName:(NSString *)name content:(NSString *)content url:(NSString *)url {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sources = [self getAllSources];
    NSString *sourceId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *source = @{
                             @"id": sourceId,
                             @"name": name ?: LocalizedString(@"unnamed_source"),
                             @"content": content ?: @"",
                             @"url": url ?: @""
                             };
    [sources addObject:source];
    [defs setObject:sources forKey:@"ios6_iptv_sources"];
    
    if (sources.count == 1) {
        [defs setObject:sourceId forKey:@"ios6_iptv_active_source_id"];
    }
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
}

- (void)deleteSourceAtIndex:(NSInteger)index {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sources = [self getAllSources];
    if (index >= sources.count) return;
    
    NSString *sourceId = sources[index][@"id"];
    NSString *activeId = [defs objectForKey:@"ios6_iptv_active_source_id"];
    
    [sources removeObjectAtIndex:index];
    [defs setObject:sources forKey:@"ios6_iptv_sources"];
    
    if ([sourceId isEqualToString:activeId]) {
        if (sources.count > 0) {
            [defs setObject:sources.firstObject[@"id"] forKey:@"ios6_iptv_active_source_id"];
        } else {
            [defs removeObjectForKey:@"ios6_iptv_active_source_id"];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    }
    [defs synchronize];
}

- (void)setActiveSourceById:(NSString *)sourceId {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:sourceId forKey:@"ios6_iptv_active_source_id"];
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
}

- (void)updateSourceNameAtIndex:(NSInteger)index withName:(NSString *)name {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sources = [self getAllSources];
    if (index >= sources.count) return;
    
    NSMutableDictionary *source = [sources[index] mutableCopy];
    source[@"name"] = name ?: LocalizedString(@"unnamed_source");
    sources[index] = source;
    
    [defs setObject:sources forKey:@"ios6_iptv_sources"];
    [defs synchronize];
    
    if ([source[@"id"] isEqualToString:[defs objectForKey:@"ios6_iptv_active_source_id"]]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    }
}

- (void)updateSourceContentAtIndex:(NSInteger)index withContent:(NSString *)content {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sources = [self getAllSources];
    if (index >= sources.count) return;
    
    NSMutableDictionary *source = [sources[index] mutableCopy];
    source[@"content"] = content ?: @"";
    sources[index] = source;
    
    [defs setObject:sources forKey:@"ios6_iptv_sources"];
    [defs synchronize];
    
    if ([source[@"id"] isEqualToString:[defs objectForKey:@"ios6_iptv_active_source_id"]]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    }
}

@end