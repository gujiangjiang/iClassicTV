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

// 获取默认全屏方向
+ (UIInterfaceOrientation)preferredInterfaceOrientation;

@end