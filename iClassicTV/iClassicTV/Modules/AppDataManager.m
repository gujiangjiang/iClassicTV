//
//  AppDataManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AppDataManager.h"
#import "LanguageManager.h" // 新增多语言
#import "M3UParser.h"       // 新增：引入解析器，用于提取头部 EPG URL
#import "EPGManager.h"      // 新增：用于和 EPG 的绑定数据联动同步

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
    
    // 同步清空所有绑定的 EPG
    [[EPGManager sharedManager] removeAllLinkedEPGSources];
    
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
    
    // 新增：尝试从内容中提取 x-tvg-url 并且注入 EPGManager 作为绑定的自带源
    NSString *epgUrls = [M3UParser extractEPGUrlsFromM3UString:content];
    if (epgUrls && epgUrls.length > 0) {
        [[EPGManager sharedManager] addEPGSourceWithName:source[@"name"] url:epgUrls type:@"xml" linkedM3UId:sourceId];
    }
    
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
    
    // 新增：通知 EPGManager 删掉与之绑定的自带源
    [[EPGManager sharedManager] removeEPGSourceByLinkedM3UId:sourceId];
    
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
    
    // 新增：同步修改对应绑定的 EPG 源名称
    [[EPGManager sharedManager] updateLinkedEPGSourceName:source[@"name"] forM3UId:source[@"id"]];
    
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
    
    // 新增：内容刷新时，重新读取并覆盖 EPG 绑定数据
    NSString *epgUrls = [M3UParser extractEPGUrlsFromM3UString:content];
    NSString *sourceId = source[@"id"];
    if (epgUrls && epgUrls.length > 0) {
        [[EPGManager sharedManager] addEPGSourceWithName:source[@"name"] url:epgUrls type:@"xml" linkedM3UId:sourceId];
    } else {
        // 如果新拉取的内容里没有 x-tvg-url 了，自动把以前绑定的删掉
        [[EPGManager sharedManager] removeEPGSourceByLinkedM3UId:sourceId];
    }
    
    if ([source[@"id"] isEqualToString:[defs objectForKey:@"ios6_iptv_active_source_id"]]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    }
}

@end