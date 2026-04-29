//
//  WatchListDataManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "WatchListDataManager.h"
#import "PlayerConfigManager.h" // 引入配置读取数量上限及记录模式
#import <UIKit/UIKit.h>
#import "LanguageManager.h"

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
    // 清空本地通知
    NSArray *arr = [self getAppointments];
    for (NSDictionary *info in arr) {
        [self cancelNotificationForAppointment:info];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WatchList_Appointments"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

// 获取最近播放数据
- (NSArray *)getRecentPlays {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] objectForKey:@"WatchList_RecentPlays"];
    return arr ? arr : @[];
}

// 添加最近播放数据
- (void)addRecentPlay:(NSDictionary *)channelInfo {
    if (![PlayerConfigManager enableRecentPlayTab]) return; // 如果未开启该功能，则不记录
    
    NSMutableArray *arr = [[self getRecentPlays] mutableCopy];
    NSInteger mode = [PlayerConfigManager watchListRecordMode];
    NSString *url = channelInfo[@"url"];
    NSString *name = channelInfo[@"name"];
    
    // [优化] 去重逻辑：根据用户设置的记录模式判断唯一性
    for (NSInteger i = 0; i < arr.count; i++) {
        if (mode == 0) { // 按频道名称
            if ([arr[i][@"name"] isEqualToString:name]) {
                [arr removeObjectAtIndex:i];
                break;
            }
        } else { // 按直播源URL
            if ([arr[i][@"url"] isEqualToString:url]) {
                [arr removeObjectAtIndex:i];
                break;
            }
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

// 移除特定索引的最近播放记录
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

// 获取所有收藏数据
- (NSArray *)getFavorites {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] objectForKey:@"WatchList_Favorites"];
    return arr ? arr : @[];
}

// 添加一条收藏记录
- (void)addFavorite:(NSDictionary *)channelInfo {
    NSMutableArray *arr = [[self getFavorites] mutableCopy];
    NSInteger mode = [PlayerConfigManager watchListRecordMode];
    NSString *url = channelInfo[@"url"];
    NSString *name = channelInfo[@"name"];
    
    // [优化] 去重逻辑：根据用户设置的记录模式判断唯一性
    for (NSInteger i = 0; i < arr.count; i++) {
        if (mode == 0) {
            if ([arr[i][@"name"] isEqualToString:name]) {
                [arr removeObjectAtIndex:i];
                break;
            }
        } else {
            if ([arr[i][@"url"] isEqualToString:url]) {
                [arr removeObjectAtIndex:i];
                break;
            }
        }
    }
    
    // 插入到最顶部
    [arr insertObject:channelInfo atIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_Favorites"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

// 移除特定索引的收藏记录（不发送全局通知）
- (void)removeFavoriteAtIndex:(NSInteger)index {
    NSMutableArray *arr = [[self getFavorites] mutableCopy];
    if (index >= 0 && index < arr.count) {
        [arr removeObjectAtIndex:index];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_Favorites"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

// [优化] 根据URL或频道名称精准移除收藏记录（配合新版记录模式）
- (void)removeFavoriteWithURL:(NSString *)url channelName:(NSString *)channelName {
    NSMutableArray *arr = [[self getFavorites] mutableCopy];
    NSInteger mode = [PlayerConfigManager watchListRecordMode];
    
    for (NSInteger i = 0; i < arr.count; i++) {
        if (mode == 0) {
            if (channelName && [arr[i][@"name"] isEqualToString:channelName]) {
                [arr removeObjectAtIndex:i];
                break;
            }
        } else {
            if (url && [arr[i][@"url"] isEqualToString:url]) {
                [arr removeObjectAtIndex:i];
                break;
            }
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_Favorites"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

// [优化] 判断是否已经收藏（配合新版记录模式）
- (BOOL)isFavorited:(NSString *)url channelName:(NSString *)channelName {
    if (!url && !channelName) return NO;
    NSArray *arr = [self getFavorites];
    NSInteger mode = [PlayerConfigManager watchListRecordMode];
    
    for (NSDictionary *dict in arr) {
        if (mode == 0) {
            if (channelName && [dict[@"name"] isEqualToString:channelName]) {
                return YES;
            }
        } else {
            if (url && [dict[@"url"] isEqualToString:url]) {
                return YES;
            }
        }
    }
    return NO;
}

#pragma mark - 预约管理逻辑

// 获取所有预约记录
- (NSArray *)getAppointments {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] objectForKey:@"WatchList_Appointments"];
    return arr ? arr : @[];
}

// 判断是否已经预约
- (BOOL)isAppointed:(NSString *)channelName startTime:(NSDate *)startTime {
    if (!channelName || !startTime) return NO;
    NSArray *arr = [self getAppointments];
    for (NSDictionary *dict in arr) {
        if ([dict[@"channelName"] isEqualToString:channelName] && [dict[@"startTime"] isEqualToDate:startTime]) {
            return YES;
        }
    }
    return NO;
}

// 添加预约记录并注册本地通知
- (void)addAppointment:(NSDictionary *)appointmentInfo {
    NSMutableArray *arr = [[self getAppointments] mutableCopy];
    
    // 如果已经预约过，先移除防重 (预约逻辑始终保持通过 频道+时段 判断，这能确保同一个节目的唯一性)
    for (NSInteger i = 0; i < arr.count; i++) {
        NSDictionary *dict = arr[i];
        if ([dict[@"channelName"] isEqualToString:appointmentInfo[@"channelName"]] && [dict[@"startTime"] isEqualToDate:appointmentInfo[@"startTime"]]) {
            [arr removeObjectAtIndex:i];
            break;
        }
    }
    
    [arr addObject:appointmentInfo];
    
    // 按照时间早晚排序
    [arr sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1[@"startTime"] compare:obj2[@"startTime"]];
    }];
    
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_Appointments"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 注册本地提醒通知
    [self scheduleNotificationForAppointment:appointmentInfo];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListDataDidChangeNotification" object:nil];
}

// 移除预约记录并取消通知
- (void)removeAppointment:(NSDictionary *)appointmentInfo {
    NSMutableArray *arr = [[self getAppointments] mutableCopy];
    for (NSInteger i = 0; i < arr.count; i++) {
        NSDictionary *dict = arr[i];
        if ([dict[@"channelName"] isEqualToString:appointmentInfo[@"channelName"]] && [dict[@"startTime"] isEqualToDate:appointmentInfo[@"startTime"]]) {
            [arr removeObjectAtIndex:i];
            break;
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_Appointments"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 取消本地提醒通知
    [self cancelNotificationForAppointment:appointmentInfo];
}

// 过滤掉已经过期的预约记录
- (void)filterExpiredAppointments {
    NSMutableArray *arr = [[self getAppointments] mutableCopy];
    BOOL modified = NO;
    NSDate *now = [NSDate date];
    
    for (NSInteger i = arr.count - 1; i >= 0; i--) {
        NSDictionary *dict = arr[i];
        NSDate *endTime = dict[@"endTime"];
        // 如果节目结束时间小于当前时间，说明节目已经过期
        if (endTime && [endTime compare:now] == NSOrderedAscending) {
            [self cancelNotificationForAppointment:dict]; // 顺手清理多余残留的系统通知（安全起见）
            [arr removeObjectAtIndex:i];
            modified = YES;
        }
    }
    
    if (modified) {
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"WatchList_Appointments"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

// 内部调度方法：生成 iOS 本地提醒通知
- (void)scheduleNotificationForAppointment:(NSDictionary *)info {
    NSDate *startTime = info[@"startTime"];
    NSDate *fireDate = [startTime dateByAddingTimeInterval:-5*60]; // 提前5分钟提醒
    
    // 如果提前5分钟的时间已经过了，但节目本身还没开播，直接设定为当前时间后5秒发出提醒
    if ([fireDate compare:[NSDate date]] == NSOrderedAscending) {
        if ([startTime compare:[NSDate date]] == NSOrderedDescending) {
            fireDate = [NSDate dateWithTimeIntervalSinceNow:5];
        } else {
            return; // 已经开播了就不需要定提醒了
        }
    }
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    if (notification) {
        notification.fireDate = fireDate;
        notification.timeZone = [NSTimeZone defaultTimeZone];
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"MM-dd HH:mm"];
        NSString *timeStr = [df stringFromDate:startTime];
        
        notification.alertBody = [NSString stringWithFormat:LocalizedString(@"reminder_alert_msg"), info[@"channelName"], timeStr, info[@"title"]];
        notification.soundName = UILocalNotificationDefaultSoundName;
        // [修复] 为本地通知添加角标属性，解决触发通知时不显示应用角标的问题
        notification.applicationIconBadgeNumber = 1;
        
        // [修复] 将 userInfo 的构造提取出来，并增加安全判断
        NSMutableDictionary *mutUserInfo = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                           @"isEPGReminder": @YES,
                                                                                           @"channelName": info[@"channelName"] ?: @"",
                                                                                           @"title": info[@"title"] ?: @"",
                                                                                           @"startTime": startTime ?: [NSDate date]
                                                                                           }];
        
        // [新增] 存入结束时间
        if (info[@"endTime"]) {
            mutUserInfo[@"endTime"] = info[@"endTime"];
        }
        
        // [新增] 判断并存入是否支持回放（通过检查 catchupSource 字符串是否有内容）
        BOOL supportsPlayback = (info[@"catchupSource"] && [info[@"catchupSource"] length] > 0);
        mutUserInfo[@"supportsPlayback"] = @(supportsPlayback);
        
        notification.userInfo = [mutUserInfo copy];
        
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    }
}

// 内部方法：根据字典参数匹配并取消对应的系统本地通知
- (void)cancelNotificationForAppointment:(NSDictionary *)info {
    NSArray *notifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
    for (UILocalNotification *notification in notifications) {
        NSDictionary *userInfo = notification.userInfo;
        if ([userInfo[@"isEPGReminder"] boolValue]) {
            if ([userInfo[@"channelName"] isEqualToString:info[@"channelName"]] && [userInfo[@"startTime"] isEqualToDate:info[@"startTime"]]) {
                [[UIApplication sharedApplication] cancelLocalNotification:notification];
                break;
            }
        }
    }
}

@end