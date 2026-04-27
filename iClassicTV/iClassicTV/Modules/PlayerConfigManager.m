//
//  PlayerConfigManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerConfigManager.h"

@implementation PlayerConfigManager

+ (NSInteger)preferredPlayerType {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerTypePref"];
}

+ (void)setPreferredPlayerType:(NSInteger)type {
    [[NSUserDefaults standardUserDefaults] setInteger:type forKey:@"PlayerTypePref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSInteger)preferredInterfaceOrientationPref {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
}

+ (UIInterfaceOrientation)preferredInterfaceOrientation {
    NSInteger pref = [self preferredInterfaceOrientationPref];
    if (pref == 1) return UIInterfaceOrientationLandscapeRight;
    if (pref == 2) return UIInterfaceOrientationPortrait;
    return UIInterfaceOrientationLandscapeRight; // 默认
}

+ (void)setPreferredInterfaceOrientationPref:(NSInteger)pref {
    [[NSUserDefaults standardUserDefaults] setInteger:pref forKey:@"PlayerOrientationPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 存储与读取控件样式设置（0:图标，1:文字）
+ (NSInteger)playerControlStylePref {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"PlayerControlStylePref"] == nil) {
        return 0; // 默认 0: 图标
    }
    return [defs integerForKey:@"PlayerControlStylePref"];
}

+ (void)setPlayerControlStylePref:(NSInteger)style {
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:@"PlayerControlStylePref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)showEPGInFullscreen {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"ShowEPGInFullscreenPref"] == nil) {
        return YES; // 默认开启
    }
    return [defs boolForKey:@"ShowEPGInFullscreenPref"];
}

+ (void)setShowEPGInFullscreen:(BOOL)show {
    [[NSUserDefaults standardUserDefaults] setBool:show forKey:@"ShowEPGInFullscreenPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)showTimeInFullscreen {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"ShowTimeInFullscreenPref"] == nil) {
        return YES; // 默认开启
    }
    return [defs boolForKey:@"ShowTimeInFullscreenPref"];
}

+ (void)setShowTimeInFullscreen:(BOOL)show {
    [[NSUserDefaults standardUserDefaults] setBool:show forKey:@"ShowTimeInFullscreenPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)showCatchupBadgeInFullscreen {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"ShowCatchupBadgeInFullscreenPref"] == nil) {
        return YES; // 默认开启
    }
    return [defs boolForKey:@"ShowCatchupBadgeInFullscreenPref"];
}

+ (void)setShowCatchupBadgeInFullscreen:(BOOL)show {
    [[NSUserDefaults standardUserDefaults] setBool:show forKey:@"ShowCatchupBadgeInFullscreenPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)showNetworkSpeedInFullscreen {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"ShowNetworkSpeedInFullscreenPref"] == nil) {
        return NO; // 默认关闭
    }
    return [defs boolForKey:@"ShowNetworkSpeedInFullscreenPref"];
}

+ (void)setShowNetworkSpeedInFullscreen:(BOOL)show {
    [[NSUserDefaults standardUserDefaults] setBool:show forKey:@"ShowNetworkSpeedInFullscreenPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)enableFavoritesTab {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"EnableFavoritesTabPref"] == nil) {
        return YES; // 默认开启
    }
    return [defs boolForKey:@"EnableFavoritesTabPref"];
}

+ (void)setEnableFavoritesTab:(BOOL)enable {
    [[NSUserDefaults standardUserDefaults] setBool:enable forKey:@"EnableFavoritesTabPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)enableRecentPlayTab {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"EnableRecentPlayTabPref"] == nil) {
        return YES; // 默认开启
    }
    return [defs boolForKey:@"EnableRecentPlayTabPref"];
}

+ (void)setEnableRecentPlayTab:(BOOL)enable {
    [[NSUserDefaults standardUserDefaults] setBool:enable forKey:@"EnableRecentPlayTabPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// [新增] 存储与读取最近播放上限
+ (NSInteger)recentPlayLimit {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"RecentPlayLimitPref"] == nil) {
        return 50; // 默认 50条
    }
    return [defs integerForKey:@"RecentPlayLimitPref"];
}

+ (void)setRecentPlayLimit:(NSInteger)limit {
    [[NSUserDefaults standardUserDefaults] setInteger:limit forKey:@"RecentPlayLimitPref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// [新增] 存储与读取启动默认页
+ (NSInteger)defaultStartupPage {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultStartupPagePref"];
}

+ (void)setDefaultStartupPage:(NSInteger)page {
    [[NSUserDefaults standardUserDefaults] setInteger:page forKey:@"DefaultStartupPagePref"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end