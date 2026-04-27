//
//  WatchListDataManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

// [新增] 专门用于管理收藏、最近播放、预约等列表数据的管理器，剥离控制器的耦合
@interface WatchListDataManager : NSObject

+ (instancetype)sharedManager;

// 清空相关数据
- (void)clearFavorites;
- (void)clearRecentPlays;
- (void)clearAppointments;

@end