//
//  PlayerControlView.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PlayerControlView;

@protocol PlayerControlViewDelegate <NSObject>
- (void)controlViewDidTapPlayPause:(PlayerControlView *)controlView;
- (void)controlViewDidTapFullscreen:(PlayerControlView *)controlView;
- (void)controlView:(PlayerControlView *)controlView sliderValueDidChange:(float)value;
- (void)controlView:(PlayerControlView *)controlView controlsHiddenDidChange:(BOOL)isHidden;
@end

@interface PlayerControlView : UIView

@property (nonatomic, weak) id<PlayerControlViewDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isLocked; // 暴露给控制器用于辅助判断顶部导航栏的隐藏逻辑

- (void)updateLayoutForFullscreen:(BOOL)isFullscreen videoFrame:(CGRect)videoFrame;
- (void)updateProgressWithValue:(float)value;
- (void)updatePlayButtonState:(BOOL)isPlaying;
- (void)updateFullscreenButtonState:(BOOL)isFullscreen;
- (void)showStatusMessage:(NSString *)message;
- (void)hideStatusMessage;
- (void)cancelAutoHideTimer;

// 新增：用于更新全屏模式下的半透明 EPG 悬浮窗内容
- (void)updateCurrentProgram:(NSString *)current nextProgram:(NSString *)next;

@end