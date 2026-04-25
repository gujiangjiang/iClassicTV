//
//  EPGManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EPGProgram.h"

@interface EPGManager : NSObject

+ (instancetype)sharedManager;

// 全局电子节目单功能开关
@property (nonatomic, assign) BOOL isEPGEnabled;

// 打开软件自动静默更新 EPG 开关
@property (nonatomic, assign) BOOL autoUpdateOnLaunch;

// [新增] 发现节目单过期时自动后台静默刷新
@property (nonatomic, assign) BOOL autoUpdateOnExpire;

// [新增] 定时刷新时间，格式为 "HH:mm"，例如 "00:30"
@property (nonatomic, copy) NSString *scheduledUpdateTimeString;

// [新增] 获取上一次成功更新 EPG 数据的时间
@property (nonatomic, readonly, strong) NSDate *lastEPGUpdateTime;

// EPG 节目单使用的时区（默认跟随设备系统时区）
@property (nonatomic, strong) NSTimeZone *epgTimeZone;

// 新增：EPG 列表无操作后自动回正到当前节目的延迟时间（秒），0 表示不自动返回
@property (nonatomic, assign) NSInteger autoScrollTimeout;

// 当前获取的 EPG 接口 URL（动态计算当前活跃的接口）
@property (nonatomic, readonly, copy) NSString *epgSourceURL;

// 当前激活的 EPG 源类型 ("xml", "diyp", "epginfo")
@property (nonatomic, readonly, copy) NSString *epgSourceType;

// 判断当前是否为动态获取的 EPG 源（DIYP / EPGInfo）
@property (nonatomic, readonly, assign) BOOL isDynamicEPGSource;

// 全部 EPG 源列表 (包含 name, url, type, isActive, linkedM3UId)
@property (nonatomic, readonly, strong) NSArray *epgSources;

// EPG 源管理方法 (支持普通源添加)
- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url type:(NSString *)type;

// 新增：添加带 M3U 绑定关系的专用内置 EPG 源
- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url type:(NSString *)type linkedM3UId:(NSString *)linkedM3UId;

// 删除/修改普通源
- (void)removeEPGSourceAtIndex:(NSInteger)index;
- (void)renameEPGSourceAtIndex:(NSInteger)index withName:(NSString *)name url:(NSString *)url type:(NSString *)type;
- (void)setActiveEPGSourceAtIndex:(NSInteger)index;

// 新增：自动管理绑定 M3U 的源 (由 AppDataManager 调用)
- (void)removeEPGSourceByLinkedM3UId:(NSString *)m3uId;
- (void)updateLinkedEPGSourceName:(NSString *)name forM3UId:(NSString *)m3uId;
- (void)removeAllLinkedEPGSources;

// --- XML 静态 EPG 管理 ---
// 异步下载并解析 EPG 数据 (内部已支持多 URL 回退互补合并)
- (void)fetchAndParseEPGDataWithCompletion:(void(^)(BOOL success, NSString *errorMsg))completion;

// 后台静默检查并自动更新
- (void)checkAndAutoUpdateEPG;

// 清理本地 EPG 缓存
- (void)clearEPGCache;

// 获取某个频道的全部节目单（内部自带模糊匹配处理）
- (NSArray *)programsForChannelName:(NSString *)channelName;

// 获取某个频道正在播放的当前节目
- (EPGProgram *)currentProgramForChannelName:(NSString *)channelName;

// --- DIYP / EPGInfo 动态 EPG 管理 ---
- (void)fetchDynamicProgramsForChannelName:(NSString *)channelName date:(NSDate *)date completion:(void(^)(NSArray *programs))completion;

@end