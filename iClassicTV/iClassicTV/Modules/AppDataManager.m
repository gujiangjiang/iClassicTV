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

// 优化：封装获取所有直播源的逻辑
- (NSMutableArray *)getAllSources {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"ios6_iptv_sources"] mutableCopy] ?: [NSMutableArray array];
}

// 优化：封装获取当前激活直播源信息的逻辑，避免在视图控制器中重复遍历
- (NSDictionary *)getActiveSourceInfo {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSArray *sources = [defs objectForKey:@"ios6_iptv_sources"];
    NSString *activeId = [defs objectForKey:@"ios6_iptv_active_source_id"];
    
    for (NSDictionary *dict in sources) {
        if ([dict[@"id"] isEqualToString:activeId]) {
            return dict;
        }
    }
    return @{@"content": @"", @"name": @"频道列表"}; // 默认后备值
}

// 优化：将原 SourceManager 中的添加逻辑提取至此
- (void)addSourceWithName:(NSString *)name content:(NSString *)content url:(NSString *)url {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sources = [self getAllSources];
    NSString *sourceId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *source = @{
                             @"id": sourceId,
                             @"name": name ?: @"未命名直播源",
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

// 优化：封装删除逻辑及越界保护
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

// 优化：封装设置激活源逻辑
- (void)setActiveSourceById:(NSString *)sourceId {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:sourceId forKey:@"ios6_iptv_active_source_id"];
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
}

// 优化：封装重命名逻辑
- (void)updateSourceNameAtIndex:(NSInteger)index withName:(NSString *)name {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sources = [self getAllSources];
    if (index >= sources.count) return;
    
    NSMutableDictionary *source = [sources[index] mutableCopy];
    source[@"name"] = name ?: @"未命名直播源";
    sources[index] = source;
    
    [defs setObject:sources forKey:@"ios6_iptv_sources"];
    [defs synchronize];
    
    if ([source[@"id"] isEqualToString:[defs objectForKey:@"ios6_iptv_active_source_id"]]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    }
}

// 优化：封装刷新内容逻辑
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