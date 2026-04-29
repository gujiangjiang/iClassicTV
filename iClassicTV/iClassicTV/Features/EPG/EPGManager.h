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

// [新增] 标识当前是否正在解析本地缓存，用于 UI 状态提示
@property (nonatomic, assign) BOOL isLoadingCache;

// [新增] 标识当前是否正在后台更新同步数据，用于 UI 状态提示
@property (nonatomic, assign) BOOL isUpdatingEPG;

// 当前获取的 EPG 接口 URL（动态计算当前活跃的接口）
@property (nonatomic, readonly, copy) NSString *epgSourceURL;

// 当前激活的 EPG 源类型 ("xml", "diyp", "epginfo")
@property (nonatomic, readonly, copy) NSString *epgSourceType;

// 判断当前是否为动态获取的 EPG 源（DIYP / EPGInfo）
@property (nonatomic, readonly, assign) BOOL isDynamicEPGSource;

// 全部 EPG 源列表 (包含 name, url, type, isActive, linkedM3UId)
@property (nonatomic, readonly, strong) NSArray *epgSources;

@end

// 引入全部分类功能模块，保证外部引用 EPGManager.h 时可直接访问所有接口
#import "EPGManager+Sources.h"
#import "EPGManager+Cache.h"
#import "EPGManager+Update.h"
#import "EPGManager+Query.h"