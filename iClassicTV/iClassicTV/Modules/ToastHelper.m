//
//  ToastHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "ToastHelper.h"
#import <QuartzCore/QuartzCore.h>

// [新增] 专门用于管理悬浮窗实例的内部视图类
@interface ToastProgressHUDView : UIView
@property (nonatomic, copy) NSString *taskKey;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@end

@implementation ToastProgressHUDView

// [修复] 显式添加 synthesize 兼容早期旧版 Xcode 编译器
@synthesize taskKey;
@synthesize titleLabel;
@synthesize progressBar;

// [修复] 将 instancetype 降级为 id 兼容早期旧版 Xcode 编译器
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
        self.layer.cornerRadius = 8.0;
        self.layer.masksToBounds = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, frame.size.width - 20, 20)];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.font = [UIFont systemFontOfSize:13];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:self.titleLabel];
        
        self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressBar.frame = CGRectMake(10, 36, frame.size.width - 20, 10);
        [self addSubview:self.progressBar];
    }
    return self;
}
@end

// [新增] 静态全局数组，用于维护当前所有正在显示的悬浮窗队列
// [修复] 移除泛型语法 <ToastProgressHUDView *> 彻底解决旧版编译器的语法解析报错
static NSMutableArray *g_activeHUDs = nil;

@implementation ToastHelper

+ (void)showToastWithMessage:(NSString *)message {
    if (!message || message.length == 0) return;
    
    // 优化：确保 UI 操作在主线程执行，防止多线程调用时引发奔溃
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
        if (!window) window = [UIApplication sharedApplication].keyWindow;
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

// [新增] 辅助方法：通过 Key 查找对应的悬浮窗实例
+ (ToastProgressHUDView *)hudForKey:(NSString *)key {
    if (!g_activeHUDs) return nil;
    for (ToastProgressHUDView *hud in g_activeHUDs) {
        if ([hud.taskKey isEqualToString:key]) {
            return hud;
        }
    }
    return nil;
}

// [新增] 辅助方法：执行栈内所有悬浮窗的重新排布动画（实现向上顶和向下回落）
+ (void)relayoutHUDsAnimated:(BOOL)animated {
    if (!g_activeHUDs || g_activeHUDs.count == 0) return;
    
    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
    if (!window) window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [[UIApplication sharedApplication].windows firstObject];
    
    CGFloat width = 160.0;
    CGFloat height = 55.0;
    CGFloat spacing = 10.0; // 悬浮窗之间的间距
    CGFloat startX = window.bounds.size.width - width - 15;
    // index 为 0 时（最新），始终紧贴右下角
    CGFloat startY = window.bounds.size.height - height - 65;
    
    [UIView animateWithDuration:(animated ? 0.3 : 0.0)
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         for (NSInteger i = 0; i < g_activeHUDs.count; i++) {
                             // [修复] 移除现代数组下标语法，改用传统 objectAtIndex 兼容老旧编译器
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
            // 如果同样 Key 的任务已经存在，仅仅重置状态，不改变其排列位置
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
        
        // 插入到首位（使其 index=0，计算坐标时位于最下方，也就是把它视为“底部新来的”）
        [g_activeHUDs insertObject:hud atIndex:0];
        
        // 触发队列排布，原有的悬浮窗会被自动往上推
        [self relayoutHUDsAnimated:YES];
        
        // 新悬浮窗执行淡入动画
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
                // 再次确保仍存在于队列中防止重复销毁
                if ([g_activeHUDs containsObject:hud]) {
                    [UIView animateWithDuration:0.3 animations:^{
                        hud.alpha = 0.0;
                    } completion:^(BOOL finished) {
                        [hud removeFromSuperview];
                        [g_activeHUDs removeObject:hud];
                        // 当前任务销毁后，上面的其他任务自动掉落回底部空缺位置
                        [self relayoutHUDsAnimated:YES];
                    }];
                }
            });
        }
    });
}

@end