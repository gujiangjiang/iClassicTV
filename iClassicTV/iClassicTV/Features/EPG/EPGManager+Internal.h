//
//  EPGManager+Internal.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"

// 将宏定义集中在内部头文件，方便各个分类模块共享调用
#define kEPGEnabledKey @"ios6_iptv_epg_enabled"
#define kEPGAutoUpdateKey @"ios6_iptv_epg_auto_update"
#define kEPGSourcesKey @"ios6_iptv_epg_sources_list"
#define kEPGTimeZoneNameKey @"ios6_iptv_epg_timezone_name"
#define kEPGAutoScrollTimeoutKey @"ios6_iptv_epg_autoscroll_timeout"

#define kEPGAutoUpdateExpireKey @"ios6_iptv_epg_auto_update_expire"
#define kEPGScheduledUpdateTimeKey @"ios6_iptv_epg_scheduled_update_time"
#define kEPGLastUpdateTimeKey @"ios6_iptv_epg_last_update_time"

// [优化] 新增：用于单独持久化缓存最大过期时间，避免每次都在主线程遍历整个大字典
#define kEPGMaxEndTimeKey @"ios6_iptv_epg_max_end_time"

@interface EPGManager ()

// 内部共享的数据变量
@property (nonatomic, strong) NSDictionary *epgCacheDict;
@property (nonatomic, strong) NSMutableArray *internalSources;

@property (nonatomic, strong) NSTimer *autoUpdateTimer;
@property (nonatomic, assign) BOOL hasTriggeredScheduledUpdateThisMinute;

// [修复] isUpdatingEPG 和 isLoadingCache 已经作为公开属性移动到了 EPGManager.h 中，此处需删除，避免重复声明导致外部无法访问
@property (nonatomic, strong) NSDate *lastFailedUpdateTime;

// [优化] 预设字符集，提高 normalizeQueryName 效率
@property (nonatomic, strong) NSCharacterSet *queryNormalizeSet;

@end