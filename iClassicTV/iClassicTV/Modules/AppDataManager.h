//
//  AppDataManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

// 数据管理核心模块
@interface AppDataManager : NSObject

+ (instancetype)sharedManager;

// 迁移旧版单源数据到新版多源架构
- (void)migrateLegacyDataIfNeeded;

// 清空所有直播源
- (void)clearAllSources;

// 清空所有线路记忆与偏好缓存
- (void)clearAllPreferencesCache;

@end