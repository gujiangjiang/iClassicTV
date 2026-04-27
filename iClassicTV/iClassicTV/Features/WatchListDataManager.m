//
//  WatchListDataManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "WatchListDataManager.h"

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

@end