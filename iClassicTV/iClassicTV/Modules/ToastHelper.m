//
//  ToastHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "ToastHelper.h"
#import <QuartzCore/QuartzCore.h> // 新增：引入 QuartzCore 用于设置圆角

// 静态全局变量，用于持有全局悬浮窗控件
static UIView *g_progressHUD = nil;
static UILabel *g_progressLabel = nil;
static UIProgressView *g_progressBar = nil;

@implementation ToastHelper

+ (void)showToastWithMessage:(NSString *)message {
    if (!message || message.length == 0) return;
    
    // 优化：确保 UI 操作在主线程执行，防止多线程调用时引发奔溃
    dispatch_async(dispatch_get_main_queue(), ^{
        // 修复：获取当前显示的顶层视图，以保证 Toast 能够正确跟随屏幕旋转
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [[UIApplication sharedApplication].windows firstObject];
        UIView *targetView = window.rootViewController.view;
        if (!targetView) targetView = window;
        
        // 限制最大宽度和设置字体
        CGFloat maxWidth = targetView.bounds.size.width - 60;
        UIFont *font = [UIFont boldSystemFontOfSize:15];
        
        // 修复：使用兼容 iOS 6 的文本尺寸计算方法，根据文字长短自动算出最贴合的尺寸
        CGSize expectedSize = [message sizeWithFont:font constrainedToSize:CGSizeMake(maxWidth - 30, 9999) lineBreakMode:NSLineBreakByWordWrapping];
        
        // 修复：创建半透明黑色背景的容器视图，彻底解决 UIAlertView 导致的底部大片留白 Bug
        UIView *toastView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, expectedSize.width + 30, expectedSize.height + 20)];
        toastView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
        toastView.layer.cornerRadius = 8.0;
        toastView.layer.masksToBounds = YES;
        
        // 居中显示
        toastView.center = CGPointMake(targetView.bounds.size.width / 2, targetView.bounds.size.height / 2);
        toastView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        // 创建纯文本 Label
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, expectedSize.width, expectedSize.height)];
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.textColor = [UIColor whiteColor];
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.font = font;
        textLabel.text = message;
        textLabel.numberOfLines = 0;
        textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        
        [toastView addSubview:textLabel];
        [targetView addSubview:toastView];
        
        // 淡入淡出动画
        toastView.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            toastView.alpha = 1.0;
        } completion:^(BOOL finished) {
            // 停留 1.5 秒后淡出并彻底移除
            [UIView animateWithDuration:0.25 delay:1.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                toastView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [toastView removeFromSuperview];
            }];
        }];
    });
}

// 新增：显示全局悬浮进度窗
+ (void)showGlobalProgressHUDWithTitle:(NSString *)title {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_progressHUD) {
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) window = [[UIApplication sharedApplication].windows firstObject];
            
            CGFloat width = 160.0;
            CGFloat height = 55.0;
            // 固定在右下角，避开底部 TabBar (通常 49pt)
            CGFloat x = window.bounds.size.width - width - 15;
            CGFloat y = window.bounds.size.height - height - 65;
            
            g_progressHUD = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
            g_progressHUD.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
            g_progressHUD.layer.cornerRadius = 8.0;
            g_progressHUD.layer.masksToBounds = YES;
            // 支持跨 tab 和屏幕旋转，始终吸附在右下角
            g_progressHUD.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
            
            g_progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, width - 20, 20)];
            g_progressLabel.backgroundColor = [UIColor clearColor];
            g_progressLabel.textColor = [UIColor whiteColor];
            g_progressLabel.font = [UIFont systemFontOfSize:13];
            g_progressLabel.textAlignment = NSTextAlignmentCenter;
            g_progressLabel.adjustsFontSizeToFitWidth = YES;
            [g_progressHUD addSubview:g_progressLabel];
            
            g_progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            g_progressBar.frame = CGRectMake(10, 36, width - 20, 10);
            [g_progressHUD addSubview:g_progressBar];
            
            [window addSubview:g_progressHUD];
        }
        
        [g_progressHUD.superview bringSubviewToFront:g_progressHUD]; // 确保显示在最前面
        g_progressHUD.alpha = 1.0;
        g_progressLabel.text = title;
        g_progressBar.progress = 0.0;
    });
}

// 新增：更新全局悬浮进度窗
+ (void)updateGlobalProgressHUD:(CGFloat)progress text:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_progressHUD) {
            if (text) g_progressLabel.text = text;
            [g_progressBar setProgress:progress animated:YES];
        }
    });
}

// 新增：隐藏全局悬浮进度窗
+ (void)dismissGlobalProgressHUDWithText:(NSString *)text delay:(NSTimeInterval)delay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_progressHUD) {
            if (text) g_progressLabel.text = text;
            [g_progressBar setProgress:1.0 animated:YES];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{
                    g_progressHUD.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [g_progressHUD removeFromSuperview];
                    g_progressHUD = nil;
                    g_progressLabel = nil;
                    g_progressBar = nil;
                }];
            });
        }
    });
}

@end