//
//  ToastHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "ToastHelper.h"
#import "UIStyleHelper.h" // 引入新模块
#import <QuartzCore/QuartzCore.h>

// 专门用于管理悬浮窗实例的内部视图类
@interface ToastProgressHUDView : UIView
@property (nonatomic, copy) NSString *taskKey;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@end

@implementation ToastProgressHUDView

@synthesize taskKey;
@synthesize titleLabel;
@synthesize progressBar;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
        
        // [优化] 使用统一模块应用背景样式
        [UIStyleHelper applyGlobalStyleToView:self];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, frame.size.width - 20, 20)];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        
        // [优化] 使用统一模块应用文字样式
        [UIStyleHelper applyTextStyleToLabel:self.titleLabel isBold:YES fontSize:13.0];
        
        [self addSubview:self.titleLabel];
        
        self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressBar.frame = CGRectMake(10, 36, frame.size.width - 20, 10);
        
        // [优化] 使用统一模块应用进度条样式
        [UIStyleHelper applyProgressStyleToView:self.progressBar];
        
        [self addSubview:self.progressBar];
    }
    return self;
}
@end

static NSMutableArray *g_activeHUDs = nil;

@implementation ToastHelper

+ (void)showToastWithMessage:(NSString *)message {
    if (!message || message.length == 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
        if (!window) window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [[UIApplication sharedApplication].windows firstObject];
        
        UIView *targetView = window.rootViewController.view;
        if (!targetView) targetView = window;
        
        CGFloat maxWidth = targetView.bounds.size.width - 60;
        // 动态获取字体
        UIFont *font = [UIStyleHelper isIOS7OrLater] ? [UIFont systemFontOfSize:15] : [UIFont boldSystemFontOfSize:15];
        
        CGSize expectedSize = [message sizeWithFont:font constrainedToSize:CGSizeMake(maxWidth - 30, 9999) lineBreakMode:NSLineBreakByWordWrapping];
        
        UIView *toastView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, expectedSize.width + 30, expectedSize.height + 20)];
        toastView.center = CGPointMake(targetView.bounds.size.width / 2, targetView.bounds.size.height / 2);
        toastView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        // [优化] 使用统一模块应用背景样式
        [UIStyleHelper applyGlobalStyleToView:toastView];
        
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, expectedSize.width, expectedSize.height)];
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.textColor = [UIColor whiteColor];
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.text = message;
        textLabel.numberOfLines = 0;
        textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        
        // [优化] 使用统一模块应用文字样式
        [UIStyleHelper applyTextStyleToLabel:textLabel isBold:YES fontSize:15.0];
        
        [toastView addSubview:textLabel];
        [targetView addSubview:toastView];
        
        toastView.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            toastView.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.25 delay:1.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                toastView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [toastView removeFromSuperview];
            }];
        }];
    });
}

+ (ToastProgressHUDView *)hudForKey:(NSString *)key {
    if (!g_activeHUDs) return nil;
    for (ToastProgressHUDView *hud in g_activeHUDs) {
        if ([hud.taskKey isEqualToString:key]) {
            return hud;
        }
    }
    return nil;
}

+ (void)relayoutHUDsAnimated:(BOOL)animated {
    if (!g_activeHUDs || g_activeHUDs.count == 0) return;
    
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    if (!window) window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [[UIApplication sharedApplication].windows firstObject];
    
    CGFloat width = 160.0;
    CGFloat height = 55.0;
    CGFloat spacing = 10.0;
    CGFloat startX = window.bounds.size.width - width - 15;
    CGFloat startY = window.bounds.size.height - height - 65;
    
    [UIView animateWithDuration:(animated ? 0.3 : 0.0)
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         for (NSInteger i = 0; i < g_activeHUDs.count; i++) {
                             ToastProgressHUDView *hud = [g_activeHUDs objectAtIndex:i];
                             CGFloat targetY = startY - i * (height + spacing);
                             hud.frame = CGRectMake(startX, targetY, width, height);
                             [hud.superview bringSubviewToFront:hud];
                         }
                     } completion:nil];
}

+ (void)showGlobalProgressHUDWithKey:(NSString *)key title:(NSString *)title {
    if (!key) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_activeHUDs) {
            g_activeHUDs = [NSMutableArray array];
        }
        
        ToastProgressHUDView *existingHUD = [self hudForKey:key];
        if (existingHUD) {
            [existingHUD.layer removeAllAnimations];
            existingHUD.alpha = 1.0;
            existingHUD.titleLabel.text = title;
            existingHUD.progressBar.progress = 0.0;
            return;
        }
        
        UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
        if (!window) window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [[UIApplication sharedApplication].windows firstObject];
        
        CGFloat width = 160.0;
        CGFloat height = 55.0;
        CGFloat startX = window.bounds.size.width - width - 15;
        CGFloat startY = window.bounds.size.height - height - 65;
        
        ToastProgressHUDView *hud = [[ToastProgressHUDView alloc] initWithFrame:CGRectMake(startX, startY, width, height)];
        hud.taskKey = key;
        hud.titleLabel.text = title;
        hud.progressBar.progress = 0.0;
        hud.alpha = 0.0;
        [window addSubview:hud];
        
        [g_activeHUDs insertObject:hud atIndex:0];
        [self relayoutHUDsAnimated:YES];
        
        [UIView animateWithDuration:0.3 animations:^{
            hud.alpha = 1.0;
        }];
    });
}

+ (void)updateGlobalProgressHUDWithKey:(NSString *)key progress:(CGFloat)progress text:(NSString *)text {
    if (!key) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        ToastProgressHUDView *hud = [self hudForKey:key];
        if (hud) {
            if (text) hud.titleLabel.text = text;
            [hud.progressBar setProgress:progress animated:YES];
        }
    });
}

+ (void)dismissGlobalProgressHUDWithKey:(NSString *)key text:(NSString *)text delay:(NSTimeInterval)delay {
    if (!key) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        ToastProgressHUDView *hud = [self hudForKey:key];
        if (hud) {
            if (text) hud.titleLabel.text = text;
            [hud.progressBar setProgress:1.0 animated:YES];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if ([g_activeHUDs containsObject:hud]) {
                    [UIView animateWithDuration:0.3 animations:^{
                        hud.alpha = 0.0;
                    } completion:^(BOOL finished) {
                        [hud removeFromSuperview];
                        [g_activeHUDs removeObject:hud];
                        [self relayoutHUDsAnimated:YES];
                    }];
                }
            });
        }
    });
}

@end