//
//  PlayerControlView.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PlayerControlView;

// 定义代理协议，将 UI 上的操作事件传递给控制器
@protocol PlayerControlViewDelegate <NSObject>
@optional
- (void)controlViewDidTapBack:(PlayerControlView *)controlView;
- (void)controlViewDidTapPlayPause:(PlayerControlView *)controlView;
- (void)controlViewDidTapFullscreen:(PlayerControlView *)controlView;
- (void)controlView:(PlayerControlView *)controlView sliderValueDidChange:(float)value;
- (void)controlView:(PlayerControlView *)controlView controlsHiddenDidChange:(BOOL)isHidden;
@end

// 独立的播放器 UI 交互面板组件
@interface PlayerControlView : UIView

@property (nonatomic, weak) id<PlayerControlViewDelegate> delegate;

// 供控制器调用的 UI 更新接口
- (void)setChannelTitle:(NSString *)title;
- (void)updateProgressWithValue:(float)value;
- (void)updatePlayButtonState:(BOOL)isPlaying;
- (void)updateFullscreenButtonState:(BOOL)isFullscreen;
- (void)showStatusMessage:(NSString *)message;
- (void)hideStatusMessage;

// 新增：主动注销自动隐藏定时器，防止在关闭播放器时引发内存泄漏或野指针异常
- (void)cancelAutoHideTimer;

// 新增：布局更新接口，用于支持非全屏半屏显示的动态适配
- (void)updateLayoutForFullscreen:(BOOL)isFullscreen videoFrame:(CGRect)videoFrame;

@end