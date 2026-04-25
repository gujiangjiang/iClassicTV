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

// 当前获取的 EPG 接口 URL（动态计算当前活跃的接口）
@property (nonatomic, readonly, copy) NSString *epgSourceURL;

// 新增：当前激活的 EPG 源类型 ("xml", "diyp", "epginfo")
@property (nonatomic, readonly, copy) NSString *epgSourceType;

// 新增：判断当前是否为动态获取的 EPG 源（DIYP / EPGInfo）
@property (nonatomic, readonly, assign) BOOL isDynamicEPGSource;

// 全部 EPG 源列表 (包含 name, url, type, isActive)
@property (nonatomic, readonly, strong) NSArray *epgSources;

// EPG 源管理方法 (新增 type 参数)
- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url type:(NSString *)type;
- (void)removeEPGSourceAtIndex:(NSInteger)index;
- (void)renameEPGSourceAtIndex:(NSInteger)index withName:(NSString *)name url:(NSString *)url type:(NSString *)type;
- (void)setActiveEPGSourceAtIndex:(NSInteger)index;

// --- XML 静态 EPG 管理 ---
// 异步下载并解析 EPG 数据 (仅针对 XML 全局格式)
- (void)fetchAndParseEPGDataWithCompletion:(void(^)(BOOL success, NSString *errorMsg))completion;

// 后台静默检查并自动更新（请在 AppDelegate 中调用）
- (void)checkAndAutoUpdateEPG;

// 清理本地 EPG 缓存
- (void)clearEPGCache;

// 获取某个频道的全部节目单（内部自带模糊匹配处理）
- (NSArray *)programsForChannelName:(NSString *)channelName;

// 获取某个频道正在播放的当前节目
- (EPGProgram *)currentProgramForChannelName:(NSString *)channelName;

// --- DIYP / EPGInfo 动态 EPG 管理 ---
// 新增：根据频道名和指定日期，动态请求节目单数据
- (void)fetchDynamicProgramsForChannelName:(NSString *)channelName date:(NSDate *)date completion:(void(^)(NSArray *programs))completion;

@end