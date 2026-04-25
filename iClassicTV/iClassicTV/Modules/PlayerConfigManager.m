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

// [新增] 存储全屏是否显示回放角标的偏好
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

@end