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

@property (nonatomic, strong) UIView *backgroundView; // 新增：底层背景容器，用于竖屏留白区域渲染
@property (nonatomic, strong) UILabel *tipsLabel;     // 新增：竖屏预留区域提示文字

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    // 修复：适配 iOS 6，确保视图占据全屏（包括状态栏区域），避免状态栏隐藏时引发布局跳动
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = YES;
    }
    
    // 新增：加入统一的底层背景视图，方便管理非全屏时的界面空白处样式
    self.backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    // 优化：移除自动拉伸属性，完全交由 viewWillLayoutSubviews 进行精准的坐标计算，防止背景穿透
    [self.view addSubview:self.backgroundView];
    
    // 新增：用于在非全屏下方预留空间显示的提示文案
    self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.tipsLabel.backgroundColor = [UIColor clearColor];
    self.tipsLabel.textAlignment = NSTextAlignmentCenter;
    self.tipsLabel.textColor = [UIColor grayColor];
    self.tipsLabel.font = [UIFont systemFontOfSize:14];
    self.tipsLabel.text = @"电子节目单功能等待完善中。";
    self.tipsLabel.numberOfLines = 0;
    [self.view addSubview:self.tipsLabel];
    
    // 1. 注册接收远程控制事件（锁屏控件、耳机线控）
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    // 2. 初始化底层播放内核
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.controlStyle = MPMovieControlStyleNone; // 隐藏系统自带 UI
    [self.view addSubview:self.player.view]; // 优化：Frame 交由 viewWillLayoutSubviews 动态算计
    
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

// 优化：通过系统回调动态计算各个组件的 Frame 尺寸，自动完美适配横竖屏
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    // 判断系统当前旋转后的方向，强制确立全屏状态标识
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    self.isFullscreen = UIInterfaceOrientationIsLandscape(orientation);
    
    [self.controlView updateFullscreenButtonState:self.isFullscreen];
    
    CGRect videoFrame;
    if (self.isFullscreen) {
        // 横屏：纯粹沉浸式全屏
        videoFrame = self.view.bounds;
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = [UIColor blackColor];
        self.tipsLabel.hidden = YES;
    } else {
        // 竖屏：避开 64px 伪导航栏高度，并以标准的 16:9 比例渲染播放器画面
        CGFloat topBarHeight = 64.0;
        CGFloat videoHeight = self.view.bounds.size.width * 9.0 / 16.0;
        videoFrame = CGRectMake(0, topBarHeight, self.view.bounds.size.width, videoHeight);
        
        // 修复：让竖屏时的背景视图从 topBar 下方开始绘制，避免灰色背景向上穿透到半透明顶栏，彻底解决“蒙了一层灰皮”的问题
        self.backgroundView.frame = CGRectMake(0, topBarHeight, self.view.bounds.size.width, self.view.bounds.size.height - topBarHeight);
        
        // 分离系统风格，iOS 7 显示淡雅灰色，iOS 6 显示经典的带纹理的亚麻布深灰
        BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        self.backgroundView.backgroundColor = isIOS7 ? [UIColor groupTableViewBackgroundColor] : [UIColor scrollViewTexturedBackgroundColor];
        
        self.tipsLabel.hidden = NO;
        self.tipsLabel.frame = CGRectMake(20, CGRectGetMaxY(videoFrame) + 30, self.view.bounds.size.width - 40, 40);
    }
    
    self.player.view.frame = videoFrame;
    
    // 同步把计算好的视频大小抛给 UI 组件层让其自适应重算内部部件
    [self.controlView updateLayoutForFullscreen:self.isFullscreen videoFrame:videoFrame];
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
        // 当前为横屏，主动退出全屏切回竖屏
        [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
    } else {
        // 当前为竖屏，主动进入全屏切至横屏
        UIInterfaceOrientation targetOrientation = [PlayerConfigManager preferredInterfaceOrientation];
        if (!UIInterfaceOrientationIsLandscape(targetOrientation)) {
            targetOrientation = UIInterfaceOrientationLandscapeRight; // 如果配置异常，兜底防呆为右横向
        }
        [self forceRotateToOrientation:targetOrientation];
    }
    
    // 主动更新状态栏可见性状态
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
    // 优化：竖屏半屏下必须常驻显示状态栏防跳动；横屏全屏下跟随播放面板控制是否隐藏
    if (!self.isFullscreen) return NO;
    return self.isControlsHidden;
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

// 新增：监听设备旋转的动画周期，为内部视图（特别是 PlayerControlView）强制增加平滑的过渡动画
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // 优化：利用系统旋转的 duration 时间，让界面元素的布局更新平滑化
    // 解决连续点击全屏切换时 [UIDevice currentDevice] setValue:... 导致的布局瞬间闪跳、生硬的问题
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.view layoutIfNeeded];
                     } completion:nil];
}

@end