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

+ (UIInterfaceOrientation)preferredInterfaceOrientation {
    NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
    if (pref == 1) return UIInterfaceOrientationLandscapeRight;
    if (pref == 2) return UIInterfaceOrientationPortrait;
    return UIInterfaceOrientationLandscapeRight; // 默认
}

@end