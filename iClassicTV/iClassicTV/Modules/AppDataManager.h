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

// 新增：清空所有频道图像缓存
- (void)clearAllChannelIcons;

// 新增：清空所有网络与临时缓存
- (void)clearAllGeneralCache;

// 新增：恢复所有默认设置
- (void)restoreAllSettings;

// 新增：获取所有直播源列表
- (NSMutableArray *)getAllSources;

// 新增：获取当前激活的直播源信息 (返回包含 content 和 name 的字典)
- (NSDictionary *)getActiveSourceInfo;

// 新增：添加新的直播源
- (void)addSourceWithName:(NSString *)name content:(NSString *)content url:(NSString *)url;

// 新增：删除指定索引的直播源
- (void)deleteSourceAtIndex:(NSInteger)index;

// 新增：设置当前激活的直播源
- (void)setActiveSourceById:(NSString *)sourceId;

// 新增：更新指定直播源的名称
- (void)updateSourceNameAtIndex:(NSInteger)index withName:(NSString *)name;

// 新增：更新指定直播源的内容 (刷新同步时使用)
- (void)updateSourceContentAtIndex:(NSInteger)index withContent:(NSString *)content;

// [新增] 从网络统一同步刷新指定直播源（封装网络请求、格式校验及提示回调）
- (void)refreshSourceFromNetworkWithId:(NSString *)sourceId completion:(void(^)(BOOL success, NSString *message))completion;

@end