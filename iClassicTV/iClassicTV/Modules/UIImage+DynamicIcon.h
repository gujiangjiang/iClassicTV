//
//  UIImage+DynamicIcon.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 全局动态图标绘制模块
@interface UIImage (DynamicIcon)

// 绘制“播放”图标 (经典播放三角形)，用于 TabBar
+ (UIImage *)dynamicPlayTabBarIcon;

// 绘制“设置”图标 (经典调节控制条样式)，用于 TabBar
+ (UIImage *)dynamicSettingsTabBarIcon;

// 动态绘制锁头图标，用于播放器防误触锁定功能
+ (UIImage *)dynamicLockIconWithState:(BOOL)locked;

// [新增] 动态绘制播放器底部的“播放/暂停”状态图标
+ (UIImage *)dynamicPlaybackIconWithState:(BOOL)isPlaying;

// [新增] 动态绘制播放器底部的“全屏/退出全屏”状态图标
+ (UIImage *)dynamicFullscreenIconWithState:(BOOL)isFullscreen;

@end