//
//  PlayerConfigManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 播放器配置读取模块
@interface PlayerConfigManager : NSObject

// 获取默认播放器类型 (0: 自定义, 1: 原生)
+ (NSInteger)preferredPlayerType;
// 设置默认播放器类型
+ (void)setPreferredPlayerType:(NSInteger)type;

// 获取默认全屏方向设置的原始值 (0: 跟随系统, 1: 横屏, 2: 竖屏)
+ (NSInteger)preferredInterfaceOrientationPref;
// 获取默认全屏方向对应的 UIInterfaceOrientation
+ (UIInterfaceOrientation)preferredInterfaceOrientation;
// 设置默认全屏方向
+ (void)setPreferredInterfaceOrientationPref:(NSInteger)pref;

// 获取全屏状态下是否显示节目单 (默认 YES)
+ (BOOL)showEPGInFullscreen;
// 设置全屏状态下是否显示节目单
+ (void)setShowEPGInFullscreen:(BOOL)show;

// 获取全屏状态下是否显示悬浮时间 (默认 YES)
+ (BOOL)showTimeInFullscreen;
// 设置全屏状态下是否显示悬浮时间
+ (void)setShowTimeInFullscreen:(BOOL)show;

// [新增] 获取全屏状态下是否显示回放标识 (默认 YES)
+ (BOOL)showCatchupBadgeInFullscreen;
// [新增] 设置全屏状态下是否显示回放标识
+ (void)setShowCatchupBadgeInFullscreen:(BOOL)show;

// [新增] 获取全屏状态下是否显示实时网速 (默认 NO)
+ (BOOL)showNetworkSpeedInFullscreen;
// [新增] 设置全屏状态下是否显示实时网速
+ (void)setShowNetworkSpeedInFullscreen:(BOOL)show;

@end