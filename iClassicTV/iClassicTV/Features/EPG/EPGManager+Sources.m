//
//  EPGManager+Sources.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager+Sources.h"
#import "EPGManager+Internal.h"
#import "EPGManager+Cache.h"
#import "LanguageManager.h"
#import "ToastHelper.h" // [新增] 引入ToastHelper用于切换时清理浮窗

@implementation EPGManager (Sources)

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
            // [修复] 切换EPG接口时，强制重置更新状态并立刻移除可能卡住的全局进度浮窗
            self.isUpdatingEPG = NO;
            [ToastHelper dismissGlobalProgressHUDWithKey:@"epg_update_task" text:nil delay:0.0];
            [self clearEPGCache];
        }
    }
}

@end