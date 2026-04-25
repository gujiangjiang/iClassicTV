//
//  TVPlaybackUIComponents.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

#pragma mark - ====== 底部控制栏 ======

@protocol TVPlaybackBottomBarDelegate <NSObject>
- (void)bottomBarDidTapPlayPause;
- (void)bottomBarDidTapFullscreen;
- (void)bottomBarSliderValueChanged:(float)value;
- (void)bottomBarSliderDidTouchDown;
- (void)bottomBarSliderDidRelease;
@end

@interface TVPlaybackBottomBar : UIView
@property (nonatomic, weak) id<TVPlaybackBottomBarDelegate> delegate;

- (void)updateProgressWithValue:(float)value;
- (void)updatePlayButtonState:(BOOL)isPlaying;
- (void)updateFullscreenButtonState:(BOOL)isFullscreen;
@end


#pragma mark - ====== 悬浮信息组件 ======

@interface TVPlaybackWidgetsView : UIView

// 标识当前是否为回放模式，用于控制常驻角标的显示
@property (nonatomic, assign) BOOL isCatchupMode;

// 布局刷新
- (void)updateLayoutForFullscreen:(BOOL)isFullscreen parentSize:(CGSize)size;

// 刷新全屏双行节目单
- (void)updateCurrentProgram:(NSString *)current nextProgram:(NSString *)next;

// 刷新系统时间
- (void)updateSystemTime;

// 屏幕中央状态提示
- (void)showStatusMessage:(NSString *)message;
- (void)hideStatusMessage;

@end