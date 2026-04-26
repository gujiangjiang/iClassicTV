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
#import "NetworkManager.h"  // [新增] 用于统一下载更新
#import "ToastHelper.h"     // [新增] 用于统一UI提示
#import "M3UValidator.h"    // [新增] 用于统一校验
#import "NSString+EncodingHelper.h" // [新增] 用于处理 URL

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

// [新增] 从网络统一同步刷新指定直播源（提取合并后的独立模块）
- (void)refreshSourceFromNetworkWithId:(NSString *)sourceId completion:(void(^)(BOOL success, NSString *message))completion {
    NSDictionary *targetSource = nil;
    NSInteger targetIndex = NSNotFound;
    NSArray *sources = [self getAllSources];
    for (NSInteger i = 0; i < sources.count; i++) {
        if ([sources[i][@"id"] isEqualToString:sourceId]) {
            targetSource = sources[i];
            targetIndex = i;
            break;
        }
    }
    
    if (!targetSource) {
        if (completion) completion(NO, LocalizedString(@"refresh_failed"));
        return;
    }
    
    NSString *urlStr = targetSource[@"url"];
    if (urlStr.length == 0) {
        if (completion) completion(NO, LocalizedString(@"invalid_url"));
        return;
    }
    
    // 统一处理可能存在的特殊字符链接编码
    NSURL *url = [urlStr toSafeURL];
    if (!url) {
        if (completion) completion(NO, LocalizedString(@"invalid_url"));
        return;
    }
    
    [ToastHelper showGlobalProgressHUDWithTitle:LocalizedString(@"syncing")];
    [ToastHelper updateGlobalProgressHUD:0.5 text:LocalizedString(@"syncing_msg")];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *m3uData = [[NetworkManager sharedManager] downloadStringSyncFromURL:url];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m3uData && m3uData.length > 0) {
                if ([M3UValidator isValidM3UString:m3uData]) {
                    [self updateSourceContentAtIndex:targetIndex withContent:m3uData];
                    [ToastHelper dismissGlobalProgressHUDWithText:LocalizedString(@"refresh_success") delay:3.0];
                    if (completion) completion(YES, LocalizedString(@"refresh_success"));
                } else {
                    [ToastHelper dismissGlobalProgressHUDWithText:LocalizedString(@"sync_m3u_invalid") delay:3.0];
                    if (completion) completion(NO, LocalizedString(@"sync_m3u_invalid"));
                }
            } else {
                [ToastHelper dismissGlobalProgressHUDWithText:LocalizedString(@"refresh_failed") delay:3.0];
                if (completion) completion(NO, LocalizedString(@"refresh_failed"));
            }
        });
    });
}

@end