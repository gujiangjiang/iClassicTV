//
//  ToastHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 交互反馈模块
@interface ToastHelper : NSObject

// 模拟 iOS 风格的 Toast，自动消失
+ (void)showToastWithMessage:(NSString *)message;

// 新增：显示全局悬浮进度窗（展示在右下角，跨 Tab 和页面持续显示）
+ (void)showGlobalProgressHUDWithTitle:(NSString *)title;

// 新增：更新全局悬浮进度窗的进度和文字
+ (void)updateGlobalProgressHUD:(CGFloat)progress text:(NSString *)text;

// 新增：完成刷新，显示提示文字，并延迟指定时间后消失
+ (void)dismissGlobalProgressHUDWithText:(NSString *)text delay:(NSTimeInterval)delay;

@end