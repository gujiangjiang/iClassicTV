//
//  TVPlaybackViewController+UI.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController+UI.h"
#import "TVPlaybackViewController+Internal.h"

@implementation TVPlaybackViewController (UI)

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    [self.overlayView.bottomBar updateFullscreenButtonState:self.isFullscreen];
    
    CGRect videoFrame;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    if (self.isFullscreen) {
        // 全屏模式下，视频区域占满屏幕，无顶部偏移
        videoFrame = self.view.bounds;
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = [UIColor blackColor];
        
        self.epgContainerView.hidden = YES;
        self.epgView.hidden = YES;
        
    } else {
        // [修复] 剥离 topOffset 计算：通过 UIRectEdgeNone 原生特性支持，Y=0 即可完美对齐导航栏底边！
        videoFrame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width * 9.0 / 16.0);
        
        self.backgroundView.frame = self.view.bounds;
        // [优化] 使用经典的 iOS 6 浅灰纹理色作为底层，让纯白的 EPG 区域更有层次感
        self.backgroundView.backgroundColor = isIOS7 ? [UIColor groupTableViewBackgroundColor] : [UIColor scrollViewTexturedBackgroundColor];
        
        CGFloat tableY = CGRectGetMaxY(videoFrame);
        CGFloat tableHeight = self.view.bounds.size.height - tableY;
        
        // [优化] 增加边距，使 EPG 区域看起来像是一个嵌入式的卡片
        CGFloat padding = 10.0;
        self.epgContainerView.frame = CGRectMake(padding, tableY + padding, self.view.bounds.size.width - padding * 2, tableHeight - padding * 2);
        self.epgContainerView.layer.cornerRadius = 8.0;
        self.epgContainerView.layer.masksToBounds = NO; // 允许阴影显示
        self.epgContainerView.hidden = NO;
        
        // EPG 视图填满容器
        self.epgView.frame = self.epgContainerView.bounds;
        self.epgView.layer.cornerRadius = 8.0;
        self.epgView.layer.masksToBounds = YES;
        self.epgView.hidden = NO;
        self.epgView.backgroundColor = [UIColor whiteColor];
    }
    
    // 统一处理 iOS 6 导航栏坐标
    if (!isIOS7 && !self.navigationController.navigationBarHidden) {
        CGRect navFrame = self.navigationController.navigationBar.frame;
        BOOL isLocked = self.overlayView.isLocked;
        BOOL shouldHideStatusBar = self.isFullscreen ? (self.isControlsHidden || isLocked) : NO;
        CGFloat expectedY = shouldHideStatusBar ? 0.0 : 20.0;
        if (navFrame.origin.y != expectedY) {
            navFrame.origin.y = expectedY;
            self.navigationController.navigationBar.frame = navFrame;
        }
    }
    
    self.player.view.frame = videoFrame;
    [self.overlayView updateLayoutForFullscreen:self.isFullscreen videoFrame:videoFrame];
}

// 手动更新界面以适配全屏模式的展开或收起（不发生物理设备旋转时调用）
- (void)updateFullscreenUIState {
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    BOOL isLocked = self.overlayView.isLocked;
    
    // [修复] 原生级布局特性：在动画执行前，动态重置布局边缘限制，根除手动算偏移量带来的误差
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = self.isFullscreen ? UIRectEdgeAll : UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = self.isFullscreen;
    }
    
    // 更新全屏状态时，实时将导航栏变为透明悬浮
    self.navigationController.navigationBar.translucent = (self.isFullscreen || isIOS7) ? YES : NO;
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        if (!isIOS7) {
            BOOL shouldHideStatusBar = self.isFullscreen ? (self.isControlsHidden || isLocked) : NO;
            [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationFade];
            [[UIApplication sharedApplication] setStatusBarStyle:(self.isFullscreen ? UIStatusBarStyleBlackTranslucent : UIStatusBarStyleBlackOpaque) animated:YES];
        }
    }
    
    if (isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        BOOL shouldHideNav = self.isFullscreen ? self.isControlsHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHideNav animated:YES];
    }
    
    // [优化] 动画开始前先将全屏挂件彻底透明隐藏，避免过渡形变期间文字提前突兀出现导致错位
    [self.overlayView.widgetsView setOverlaysHidden:YES];
    
    [UIView animateWithDuration:0.35 animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        // [修复] 非锁屏状态下，挂件显隐彻底与播放控制栏状态同步
        if (!self.overlayView.isLocked) {
            [UIView animateWithDuration:0.25 animations:^{
                [self.overlayView.widgetsView setOverlaysHidden:(self.isFullscreen ? self.isControlsHidden : NO)];
            }];
        }
    }];
}

- (void)forceRotateToOrientation:(UIInterfaceOrientation)orientation {
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationUnknown] forKey:@"orientation"];
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:orientation] forKey:@"orientation"];
    [UIView animateWithDuration:0.35 animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
}

- (BOOL)prefersStatusBarHidden {
    // 锁屏状态下彻底强制隐藏状态栏
    if (self.isFullscreen && self.overlayView.isLocked) return YES;
    return self.isFullscreen ? self.isControlsHidden : NO;
}

- (BOOL)shouldAutorotate { return YES; }

- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAllButUpsideDown; }

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    if (!isIOS7) {
        BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
        
        // 旋转即将发生时，即将变成全屏的条件：要么转到横屏必然全屏，要么当前已经处于“手动全屏”且即将转到竖屏
        BOOL isGoingFullscreen = isLandscape || self.isManualFullscreen;
        BOOL isLocked = self.overlayView.isLocked;
        BOOL shouldHideStatusBar = isGoingFullscreen ? (self.isControlsHidden || isLocked) : NO;
        
        [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationNone];
        // 旋转前确保如果即将变成全屏，则采用透明悬浮样式
        [[UIApplication sharedApplication] setStatusBarStyle:(isGoingFullscreen ? UIStatusBarStyleBlackTranslucent : UIStatusBarStyleBlackOpaque) animated:NO];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
    
    // 用户物理旋转了设备核心逻辑：
    // 如果转到横屏，必定是全屏。
    // 如果转到竖屏，只有在用户开启了“手动全屏”记忆的状态下才保持全屏，否则自动退出全屏。
    if (isLandscape) {
        self.isFullscreen = YES;
    } else {
        self.isFullscreen = self.isManualFullscreen;
    }
    
    // [修复] 原生级布局特性：随旋转方向改变同步动态设置布局延伸限制
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = self.isFullscreen ? UIRectEdgeAll : UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = self.isFullscreen;
    }
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    // 导航栏的透明度跟随最终确认的全屏状态
    self.navigationController.navigationBar.translucent = (self.isFullscreen || isIOS7) ? YES : NO;
    
    if (self.overlayView.isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        BOOL shouldHide = self.isFullscreen ? self.isControlsHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHide animated:YES];
    }
    
    // 动画开始前先将全屏挂件彻底透明隐藏，避免过渡形变期间文字提前突兀出现导致错位
    [self.overlayView.widgetsView setOverlaysHidden:YES];
    
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        // [修复] 旋转动画彻底结束后，非锁屏状态下挂件显隐彻底与播放控制栏状态同步
        if (!self.overlayView.isLocked) {
            [UIView animateWithDuration:0.25 animations:^{
                [self.overlayView.widgetsView setOverlaysHidden:(self.isFullscreen ? self.isControlsHidden : NO)];
            }];
        }
    }];
}

@end