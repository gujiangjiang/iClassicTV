//
//  TVPlaybackOverlayView.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TVPlaybackUIComponents.h"

@protocol TVPlaybackOverlayDelegate <NSObject>
- (void)overlayDidTapPlayPause;
- (void)overlayDidTapFullscreen;
- (void)overlaySliderValueChanged:(float)value;
- (void)overlayControlsHiddenDidChange:(BOOL)isHidden;
@end

@interface TVPlaybackOverlayView : UIView

@property (nonatomic, weak) id<TVPlaybackOverlayDelegate> delegate;

// 暴露出两个独立职责的组件供外部更新状态
@property (nonatomic, strong, readonly) TVPlaybackBottomBar *bottomBar;
@property (nonatomic, strong, readonly) TVPlaybackWidgetsView *widgetsView;

@property (nonatomic, assign, readonly) BOOL isLocked;

// 布局同步
- (void)updateLayoutForFullscreen:(BOOL)isFullscreen videoFrame:(CGRect)videoFrame;

// [核心修复] 将系统播放状态和用户手动暂停状态拆分为两个独立的方法，避免互相干扰
- (void)updatePlaybackState:(BOOL)isPlaying;
- (void)setManualPausedState:(BOOL)isManualPaused;

// 代理中央状态提示
- (void)showStatusMessage:(NSString *)message;
- (void)hideStatusMessage;

// 生命周期管理
- (void)cancelAutoHideTimer;

@end