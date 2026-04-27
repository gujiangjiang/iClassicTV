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

// [新增] 获取播放器控件样式 (0: 图标, 1: 文字)
+ (NSInteger)playerControlStylePref;
// [新增] 设置播放器控件样式
+ (void)setPlayerControlStylePref:(NSInteger)style;

// 获取全屏状态下是否显示节目单 (默认 YES)
+ (BOOL)showEPGInFullscreen;
// 设置全屏状态下是否显示节目单
+ (void)setShowEPGInFullscreen:(BOOL)show;

// 获取全屏状态下是否显示悬浮时间 (默认 YES)
+ (BOOL)showTimeInFullscreen;
// 设置全屏状态下是否显示悬浮时间
+ (void)setShowTimeInFullscreen:(BOOL)show;

// 获取全屏状态下是否显示回放标识 (默认 YES)
+ (BOOL)showCatchupBadgeInFullscreen;
// 设置全屏状态下是否显示回放标识
+ (void)setShowCatchupBadgeInFullscreen:(BOOL)show;

// 获取全屏状态下是否显示实时网速 (默认 NO)
+ (BOOL)showNetworkSpeedInFullscreen;
// 设置全屏状态下是否显示实时网速
+ (void)setShowNetworkSpeedInFullscreen:(BOOL)show;

// 获取是否启用收藏功能 (默认 YES)
+ (BOOL)enableFavoritesTab;
// 设置是否启用收藏功能
+ (void)setEnableFavoritesTab:(BOOL)enable;

// 获取是否启用最近播放功能 (默认 YES)
+ (BOOL)enableRecentPlayTab;
// 设置是否启用最近播放功能
+ (void)setEnableRecentPlayTab:(BOOL)enable;

// [新增] 获取最近播放数量上限 (默认 50)
+ (NSInteger)recentPlayLimit;
// [新增] 设置最近播放数量上限
+ (void)setRecentPlayLimit:(NSInteger)limit;

// [新增] 获取打开软件默认主页 (0: 频道列表, 1: 我的电视)
+ (NSInteger)defaultStartupPage;
// [新增] 设置打开软件默认主页
+ (void)setDefaultStartupPage:(NSInteger)page;

@end