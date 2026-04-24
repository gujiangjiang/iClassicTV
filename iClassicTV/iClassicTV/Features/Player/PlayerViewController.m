//
//  PlayerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "PlayerConfigManager.h"
// 引入刚刚新建的 UI 组件
#import "PlayerControlView.h"

@interface PlayerViewController () <PlayerControlViewDelegate> // 遵守代理协议

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) PlayerControlView *controlView; // UI 面板层

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;
@property (nonatomic, assign) UIInterfaceOrientation originalOrientation;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    // 修复：适配 iOS 6，确保视图占据全屏（包括状态栏区域），避免状态栏隐藏时引发布局跳动
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = YES;
    }
    
    self.isFullscreen = NO;
    self.originalOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // 1. 注册接收远程控制事件（锁屏控件、耳机线控）
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    // 2. 初始化底层播放内核
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.view.frame = self.view.bounds;
    self.player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.player.controlStyle = MPMovieControlStyleNone; // 隐藏系统自带 UI
    [self.view addSubview:self.player.view];
    
    // 3. 挂载分离出去的独立 UI 组件
    self.controlView = [[PlayerControlView alloc] initWithFrame:self.view.bounds];
    self.controlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.controlView.delegate = self; // 成为控制面板的代理
    [self.controlView setChannelTitle:self.channelTitle];
    [self.view addSubview:self.controlView];
    
    // 4. 监听内核状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadStateChanged) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaTypesAvailable) name:MPMovieMediaTypesAvailableNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    // 5. 开始播放并推送到锁屏面板
    [self.player play];
    [self startTimer];
    [self updateNowPlayingInfo];
}

#pragma mark - PlayerControlViewDelegate (响应 UI 层的点击操作)

- (void)controlViewDidTapBack:(PlayerControlView *)controlView {
    [self closePlayer];
}

- (void)controlViewDidTapPlayPause:(PlayerControlView *)controlView {
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        [self.player pause];
    } else {
        [self.player play];
    }
}

- (void)controlViewDidTapFullscreen:(PlayerControlView *)controlView {
    if (self.isFullscreen) {
        self.isFullscreen = NO;
        [self.controlView updateFullscreenButtonState:NO];
        [self forceRotateToOrientation:self.originalOrientation];
    } else {
        self.isFullscreen = YES;
        [self.controlView updateFullscreenButtonState:YES];
        self.originalOrientation = [UIApplication sharedApplication].statusBarOrientation;
        UIInterfaceOrientation targetOrientation = [PlayerConfigManager preferredInterfaceOrientation];
        [self forceRotateToOrientation:targetOrientation];
    }
    
    // 修复：全屏状态改变后，立刻主动刷新状态栏的显隐状态，实现真正的沉浸式全屏
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:[self prefersStatusBarHidden] withAnimation:UIStatusBarAnimationFade];
    }
}

- (void)controlView:(PlayerControlView *)controlView sliderValueDidChange:(float)value {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = value * self.player.duration;
    }
}

- (void)controlView:(PlayerControlView *)controlView controlsHiddenDidChange:(BOOL)isHidden {
    self.isControlsHidden = isHidden;
    // 触发更新系统状态栏显示/隐藏
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        // 修复：使用全新 prefersStatusBarHidden 逻辑来决定是否隐藏
        [[UIApplication sharedApplication] setStatusBarHidden:[self prefersStatusBarHidden] withAnimation:UIStatusBarAnimationFade];
    }
}

#pragma mark - 系统锁屏控制支持

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPlay:
                [self.player play];
                break;
            case UIEventSubtypeRemoteControlPause:
                [self.player pause];
                break;
            case UIEventSubtypeRemoteControlTogglePlayPause:
                if (self.player.playbackState == MPMoviePlaybackStatePlaying) [self.player pause];
                else [self.player play];
                break;
            default:
                break;
        }
    }
}

- (void)updateNowPlayingInfo {
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        [info setObject:(self.channelTitle ?: @"未知频道") forKey:MPMediaItemPropertyTitle];
        if (self.channelLogo) {
            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:self.channelLogo];
            [info setObject:artwork forKey:MPMediaItemPropertyArtwork];
        }
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
    }
}

#pragma mark - 播放状态反馈同步给 UI 层

- (void)loadStateChanged {
    if (self.player.loadState & MPMovieLoadStateStalled) {
        [self.controlView showStatusMessage:@"缓冲中..."];
    } else if ((self.player.loadState & MPMovieLoadStatePlayable) || (self.player.loadState & MPMovieLoadStatePlaythroughOK)) {
        if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 &&
            (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
            [self.controlView showStatusMessage:@"📻\n\n电台或纯音频源 / 无画面信号"];
        } else {
            [self.controlView hideStatusMessage];
        }
    }
}

- (void)mediaTypesAvailable {
    if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 &&
        (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
        [self.controlView showStatusMessage:@"📻\n\n电台或纯音频源 / 无画面信号"];
    } else if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) != 0) {
        if (self.player.loadState & MPMovieLoadStatePlayable || self.player.loadState & MPMovieLoadStatePlaythroughOK) {
            [self.controlView hideStatusMessage];
        }
    }
}

- (void)playbackStateChanged {
    [self.controlView updatePlayButtonState:(self.player.playbackState == MPMoviePlaybackStatePlaying)];
}

- (void)playbackDidFinish:(NSNotification *)notification {
    NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if (reason != nil && [reason integerValue] == MPMovieFinishReasonPlaybackError) {
        [self.controlView showStatusMessage:@"❌\n\n播放失败或设备不支持该视频格式"];
    }
}

#pragma mark - 核心工具方法

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)updateProgress {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        float progress = self.player.currentPlaybackTime / self.player.duration;
        [self.controlView updateProgressWithValue:progress];
    }
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
    // 修复：只要是全屏模式，就永远强制隐藏状态栏；非全屏时才跟随控制面板的显隐状态
    return self.isFullscreen || self.isControlsHidden;
}

- (void)closePlayer {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) {
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    }
    
    if (![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    }
    
    [self.timer invalidate];
    self.timer = nil;
    
    // 主动注销 UI 控制层的自动隐藏定时器，防止组件延迟销毁或内存泄漏
    [self.controlView cancelAutoHideTimer];
    
    [self.player stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end