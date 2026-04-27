//
//  WatchListDataManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "WatchListDataManager.h"
#import "PlayerConfigManager.h" // 引入配置读取数量上限

@implementation WatchListDataManager

+ (instancetype)sharedManager {
    static WatchListDataManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (void)clearFavorites {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WatchList_Favorites"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

- (void)clearRecentPlays {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WatchList_RecentPlays"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

- (void)clearAppointments {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WatchList_Appointments"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

// [新增] 获取最近播放数据
- (NSArray *)getRecentPlays {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] objectForKey:@"WatchList_RecentPlays"];
    return arr ? arr : @[];
}

// [新增] 添加最近播放数据
- (void)addRecentPlay:(NSDictionary *)channelInfo {
    if (![PlayerConfigManager enableRecentPlayTab]) return; // 如果未开启该功能，则不记录
    
    NSMutableArray *arr = [[self getRecentPlays] mutableCopy];
    NSString *url = channelInfo[@"url"];
    
    // 去重逻辑：如果已经存在相同的播放链接，先将其移除，然后放到最前面
    for (NSInteger i = 0; i < arr.count; i++) {
        if ([arr[i][@"url"] isEqualToString:url]) {
            [arr removeObjectAtIndex:i];
            break;
        }
    }
    
    // 插入到最顶部
    [arr insertObject:channelInfo atIndex:0];
    
    // 数量上限检查，根据设置的上限截断多余记录
    NSInteger limit = [PlayerConfigManager recentPlayLimit];
    if (arr.count > limit) {
        [arr removeObjectsInRange:NSMakeRange(limit, arr.count - limit)];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_RecentPlays"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

// [新增] 移除特定索引的最近播放记录
- (void)removeRecentPlayAtIndex:(NSInteger)index {
    NSMutableArray *arr = [[self getRecentPlays] mutableCopy];
    if (index >= 0 && index < arr.count) {
        [arr removeObjectAtIndex:index];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_RecentPlays"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        // 注意：这里故意不发送 WatchListDataDidChangeNotification 通知，
        // 目的是为了让调用方 UI (UITableView) 能够执行平滑的左滑删除动画，而不被全局重载打断
    }
}

@end