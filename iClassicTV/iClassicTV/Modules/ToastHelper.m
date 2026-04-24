//
//  ToastHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "ToastHelper.h"
#import <QuartzCore/QuartzCore.h> // 新增：引入 QuartzCore 用于设置圆角

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

@end