//
//  ToastHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ToastHelper : NSObject

// 显示普通的中部悬浮文字提示 (短暂显示后消失)
+ (void)showToastWithMessage:(NSString *)message;

// [新增] 在指定视图中显示悬浮文字提示 (短暂显示后消失)
+ (void)showToast:(NSString *)message inView:(UIView *)view;

// [修改] 带唯一任务标识 (Key) 的全局悬浮进度窗，支持多开队列和向上顶出的自动堆叠动画
+ (void)showGlobalProgressHUDWithKey:(NSString *)key title:(NSString *)title;

// [修改] 更新指定 Key 的悬浮窗进度
+ (void)updateGlobalProgressHUDWithKey:(NSString *)key progress:(CGFloat)progress text:(NSString *)text;

// [修改] 标记指定 Key 的悬浮窗完成并延时销毁，触发自动回落动画
+ (void)dismissGlobalProgressHUDWithKey:(NSString *)key text:(NSString *)text delay:(NSTimeInterval)delay;

@end