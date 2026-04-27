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

// 最近播放功能接口
// 获取所有最近播放记录
- (NSArray *)getRecentPlays;
// 添加一条最近播放记录
- (void)addRecentPlay:(NSDictionary *)channelInfo;
// 删除指定索引的最近播放记录（不触发全局刷新通知，方便UI做删除动画）
- (void)removeRecentPlayAtIndex:(NSInteger)index;

// [新增] 收藏功能接口
// 获取所有收藏记录
- (NSArray *)getFavorites;
// 添加一条收藏记录
- (void)addFavorite:(NSDictionary *)channelInfo;
// 删除指定索引的收藏记录（用于左滑删除）
- (void)removeFavoriteAtIndex:(NSInteger)index;
// 根据URL删除指定的收藏记录（用于播放页取消收藏）
- (void)removeFavoriteWithURL:(NSString *)url;
// 判断某个URL是否已经被收藏
- (BOOL)isFavorited:(NSString *)url;

@end