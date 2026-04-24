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
#import "PlayerControlView.h"

@interface PlayerViewController () <PlayerControlViewDelegate>

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) PlayerControlView *controlView;

@property (nonatomic, strong) UINavigationBar *navBar; // 新增：接管原生的顶部导航栏
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UILabel *tipsLabel;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = YES;
    }
    
    self.backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.backgroundView];
    
    self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.tipsLabel.backgroundColor = [UIColor clearColor];
    self.tipsLabel.textAlignment = NSTextAlignmentCenter;
    self.tipsLabel.textColor = [UIColor grayColor];
    self.tipsLabel.font = [UIFont systemFontOfSize:14];
    self.tipsLabel.text = @"电子节目单功能等待完善中。";
    self.tipsLabel.numberOfLines = 0;
    [self.view addSubview:self.tipsLabel];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:self.player.view];
    
    // 挂载控制层 (纯净版)
    self.controlView = [[PlayerControlView alloc] initWithFrame:self.view.bounds];
    self.controlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.controlView.delegate = self;
    [self.view addSubview:self.controlView];
    
    // 新增：构建并挂载真正的系统原生 UINavigationBar 放在最顶层
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:self.channelTitle ?: @"未知频道"];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStyleBordered target:self action:@selector(closePlayer)];
    navItem.leftBarButtonItem = backItem;
    [self.navBar pushNavigationItem:navItem animated:NO];
    [self.view addSubview:self.navBar];
    
    // 监听内核状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadStateChanged) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaTypesAvailable) name:MPMovieMediaTypesAvailableNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    [self.player play];
    [self startTimer];
    [self updateNowPlayingInfo];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    self.isFullscreen = UIInterfaceOrientationIsLandscape(orientation);
    
    [self.controlView updateFullscreenButtonState:self.isFullscreen];
    
    CGRect videoFrame;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    if (self.isFullscreen) {
        videoFrame = self.view.bounds;
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = [UIColor blackColor];
        self.tipsLabel.hidden = YES;
        
        // 全屏时：原生的黑色毛玻璃导航栏
        self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
        self.navBar.barStyle = UIBarStyleBlack;
    } else {
        CGFloat topBarHeight = isIOS7 ? 64.0 : 64.0;
        CGFloat videoHeight = self.view.bounds.size.width * 9.0 / 16.0;
        videoFrame = CGRectMake(0, topBarHeight, self.view.bounds.size.width, videoHeight);
        
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = isIOS7 ? [UIColor groupTableViewBackgroundColor] : [UIColor scrollViewTexturedBackgroundColor];
        
        self.tipsLabel.hidden = NO;
        self.tipsLabel.frame = CGRectMake(20, CGRectGetMaxY(videoFrame) + 30, self.view.bounds.size.width - 40, 40);
        
        // 竖屏时：完全跟随 iOS 版本的原生状态栏与导航栏布局
        if (isIOS7) {
            self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 64);
            self.navBar.barStyle = UIBarStyleDefault; // 系统经典浅色
        } else {
            self.navBar.frame = CGRectMake(0, 20, self.view.bounds.size.width, 44); // 避开 iOS6 状态栏
            self.navBar.barStyle = UIBarStyleBlack;   // iOS6 经典深色高光
        }
    }
    
    // 即时更新导航栏隐藏状态，避免旋转时跳动
    if (self.controlView.isLocked) {
        self.navBar.alpha = 0.0;
    } else {
        self.navBar.alpha = (!self.isFullscreen) ? 1.0 : (self.isControlsHidden ? 0.0 : 1.0);
    }
    
    self.player.view.frame = videoFrame;
    [self.controlView updateLayoutForFullscreen:self.isFullscreen videoFrame:videoFrame];
}

#pragma mark - PlayerControlViewDelegate

- (void)controlViewDidTapPlayPause:(PlayerControlView *)controlView {
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) [self.player pause];
    else [self.player play];
}

- (void)controlViewDidTapFullscreen:(PlayerControlView *)controlView {
    if (self.isFullscreen) [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
    else {
        UIInterfaceOrientation target = [PlayerConfigManager preferredInterfaceOrientation];
        if (!UIInterfaceOrientationIsLandscape(target)) target = UIInterfaceOrientationLandscapeRight;
        [self forceRotateToOrientation:target];
    }
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) [self setNeedsStatusBarAppearanceUpdate];
    else [[UIApplication sharedApplication] setStatusBarHidden:[self prefersStatusBarHidden] withAnimation:UIStatusBarAnimationFade];
}

- (void)controlView:(PlayerControlView *)controlView sliderValueDidChange:(float)value {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = value * self.player.duration;
    }
}

- (void)controlView:(PlayerControlView *)controlView controlsHiddenDidChange:(BOOL)isHidden {
    self.isControlsHidden = isHidden;
    
    // 联动系统原生导航栏执行淡入淡出
    [UIView animateWithDuration:0.3 animations:^{
        if (controlView.isLocked) {
            self.navBar.alpha = 0.0;
        } else {
            self.navBar.alpha = (!self.isFullscreen) ? 1.0 : (isHidden ? 0.0 : 1.0);
        }
    }];
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:[self prefersStatusBarHidden] withAnimation:UIStatusBarAnimationFade];
    }
}

#pragma mark - 系统支持与其他

- (BOOL)canBecomeFirstResponder { return YES; }

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) [self.player play];
        else if (event.subtype == UIEventSubtypeRemoteControlPause) [self.player pause];
        else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            if (self.player.playbackState == MPMoviePlaybackStatePlaying) [self.player pause];
            else [self.player play];
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

- (void)loadStateChanged {
    if (self.player.loadState & MPMovieLoadStateStalled) [self.controlView showStatusMessage:@"缓冲中..."];
    else if ((self.player.loadState & MPMovieLoadStatePlayable) || (self.player.loadState & MPMovieLoadStatePlaythroughOK)) {
        if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
            [self.controlView showStatusMessage:@"📻\n\n电台或纯音频源 / 无画面信号"];
        } else [self.controlView hideStatusMessage];
    }
}

- (void)mediaTypesAvailable {
    if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
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

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)updateProgress {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        [self.controlView updateProgressWithValue:(self.player.currentPlaybackTime / self.player.duration)];
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
    return self.isFullscreen;
}

- (void)closePlayer {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    
    if (![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    }
    
    [self.timer invalidate];
    self.timer = nil;
    [self.controlView cancelAutoHideTimer];
    
    [self.player stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)shouldAutorotate { return YES; }

- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAllButUpsideDown; }

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

@end