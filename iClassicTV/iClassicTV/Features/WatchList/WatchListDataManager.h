//
//  WatchListDataManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

// 专门用于管理收藏、最近播放、预约等列表数据的管理器，剥离控制器的耦合
@interface WatchListDataManager : NSObject

+ (instancetype)sharedManager;

// 清空相关数据
- (void)clearFavorites;
- (void)clearRecentPlays;
- (void)clearAppointments;

// [新增] 最近播放功能接口
// 获取所有最近播放记录
- (NSArray *)getRecentPlays;
// 添加一条最近播放记录
- (void)addRecentPlay:(NSDictionary *)channelInfo;
// 删除指定索引的最近播放记录（不触发全局刷新通知，方便UI做删除动画）
- (void)removeRecentPlayAtIndex:(NSInteger)index;

@end