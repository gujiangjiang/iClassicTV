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
#import "LanguageManager.h"
#import "PlayerEPGView.h"
#import "EPGManager.h"      // 新增：用于拉取当前和下一个节目
#import "EPGProgram.h"      // 新增：用于解析时间对象
#import "EPGManagerViewController.h" // 新增：用于跳转至 EPG 设置页面

@interface PlayerViewController () <PlayerControlViewDelegate, PlayerEPGViewDelegate> // 新增：遵守 PlayerEPGViewDelegate 协议

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) PlayerControlView *controlView;

@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;

@property (nonatomic, strong) PlayerEPGView *epgView;

// 新增：专门用于全屏悬浮窗的时间格式化器
@property (nonatomic, strong) NSDateFormatter *epgTimeFormatter;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    // 初始化悬浮窗使用的时间格式器
    self.epgTimeFormatter = [[NSDateFormatter alloc] init];
    [self.epgTimeFormatter setDateFormat:@"HH:mm"];
    
    self.backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.backgroundView];
    
    // 实例化并挂载独立的 EPG 组件模块 (负责竖屏)
    self.epgView = [[PlayerEPGView alloc] initWithFrame:CGRectZero];
    self.epgView.channelTitle = self.channelTitle;
    self.epgView.tvgName = self.tvgName;
    self.epgView.delegate = self; // 新增：设置 EPG 操作代理
    [self.view addSubview:self.epgView];
    
    [self.epgView reloadData];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:self.player.view];
    
    self.controlView = [[PlayerControlView alloc] initWithFrame:self.view.bounds];
    self.controlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.controlView.delegate = self;
    [self.view addSubview:self.controlView];
    
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:self.channelTitle ?: LocalizedString(@"unknown_channel")];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"back") style:UIBarButtonItemStyleBordered target:self action:@selector(closePlayer)];
    navItem.leftBarButtonItem = backItem;
    [self.navBar pushNavigationItem:navItem animated:NO];
    [self.view addSubview:self.navBar];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadStateChanged) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaTypesAvailable) name:MPMovieMediaTypesAvailableNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    [self.player play];
    [self startTimer];
    [self updateNowPlayingInfo];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.epgView scrollToCurrentProgram];
    });
}

// 新增：在页面每次即将展现时（包括从设置页返回时），触发一次数据重载和悬浮窗刷新
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.epgView reloadData];
    [self updateFullscreenEPGOverlay];
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
        
        // 全屏时隐藏独立的竖屏 EPG 模块
        self.epgView.hidden = YES;
        
        self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
        self.navBar.barStyle = UIBarStyleBlack;
    } else {
        CGFloat topBarHeight = isIOS7 ? 64.0 : 44.0;
        CGFloat videoHeight = self.view.bounds.size.width * 9.0 / 16.0;
        videoFrame = CGRectMake(0, topBarHeight, self.view.bounds.size.width, videoHeight);
        
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = isIOS7 ? [UIColor groupTableViewBackgroundColor] : [UIColor scrollViewTexturedBackgroundColor];
        
        CGFloat tableY = CGRectGetMaxY(videoFrame);
        CGFloat tableHeight = self.view.bounds.size.height - tableY;
        self.epgView.frame = CGRectMake(0, tableY, self.view.bounds.size.width, tableHeight);
        self.epgView.hidden = NO;
        
        if (isIOS7) {
            self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 64);
            self.navBar.barStyle = UIBarStyleDefault;
        } else {
            self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
            self.navBar.barStyle = UIBarStyleBlack;
        }
    }
    
    if (self.controlView.isLocked) {
        self.navBar.alpha = 0.0;
    } else {
        self.navBar.alpha = (!self.isFullscreen) ? 1.0 : (self.isControlsHidden ? 0.0 : 1.0);
    }
    
    self.player.view.frame = videoFrame;
    [self.controlView updateLayoutForFullscreen:self.isFullscreen videoFrame:videoFrame];
}

#pragma mark - 新增：PlayerEPGViewDelegate 代理方法实现

// 代理回调：跳转至 EPG 管理页面
- (void)epgViewDidTapSettings:(PlayerEPGView *)epgView {
    EPGManagerViewController *epgVC = [[EPGManagerViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:epgVC];
    [self presentViewController:nav animated:YES completion:nil];
}

// 代理回调：手动立即刷新 EPG 数据
- (void)epgViewDidTapRefresh:(PlayerEPGView *)epgView {
    [[EPGManager sharedManager] fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self.epgView reloadData];
                [self updateFullscreenEPGOverlay];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"刷新失败" message:errorMsg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
            }
        });
    }];
}

#pragma mark - 新增：全屏 EPG 悬浮窗数据刷新
- (void)updateFullscreenEPGOverlay {
    // 性能优化：只有开启了 EPG 且处于全屏状态时才进行数据比对
    if (![EPGManager sharedManager].isEPGEnabled || !self.isFullscreen) {
        return;
    }
    
    NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
    NSArray *programs = [[EPGManager sharedManager] programsForChannelName:epgSearchName];
    
    if (programs.count == 0) {
        [self.controlView updateCurrentProgram:nil nextProgram:nil];
        return;
    }
    
    NSDate *now = [NSDate date];
    EPGProgram *current = nil;
    EPGProgram *next = nil;
    
    for (NSInteger i = 0; i < programs.count; i++) {
        EPGProgram *p = programs[i];
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            current = p;
            if (i + 1 < programs.count) {
                next = programs[i + 1];
            }
            break;
        }
    }
    
    NSString *currentStr = current ? [NSString stringWithFormat:@"%@ 正在播放：%@", [self.epgTimeFormatter stringFromDate:current.startTime], current.title] : @"正在播放：暂无节目数据";
    NSString *nextStr = next ? [NSString stringWithFormat:@"%@ 即将播放：%@", [self.epgTimeFormatter stringFromDate:next.startTime], next.title] : @"即将播放：暂无节目数据";
    
    [self.controlView updateCurrentProgram:currentStr nextProgram:nextStr];
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
}

- (void)controlView:(PlayerControlView *)controlView sliderValueDidChange:(float)value {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = value * self.player.duration;
    }
}

- (void)controlView:(PlayerControlView *)controlView controlsHiddenDidChange:(BOOL)isHidden {
    self.isControlsHidden = isHidden;
    
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
        [info setObject:(self.channelTitle ?: LocalizedString(@"unknown_channel")) forKey:MPMediaItemPropertyTitle];
        if (self.channelLogo) {
            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:self.channelLogo];
            [info setObject:artwork forKey:MPMediaItemPropertyArtwork];
        }
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
    }
}

- (void)loadStateChanged {
    if (self.player.loadState & MPMovieLoadStateStalled) [self.controlView showStatusMessage:LocalizedString(@"buffering")];
    else if ((self.player.loadState & MPMovieLoadStatePlayable) || (self.player.loadState & MPMovieLoadStatePlaythroughOK)) {
        if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
            [self.controlView showStatusMessage:LocalizedString(@"audio_only_signal")];
        } else [self.controlView hideStatusMessage];
    }
}

- (void)mediaTypesAvailable {
    if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
        [self.controlView showStatusMessage:LocalizedString(@"audio_only_signal")];
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
        [self.controlView showStatusMessage:LocalizedString(@"playback_failed")];
    }
}

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)updateProgress {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        [self.controlView updateProgressWithValue:(self.player.currentPlaybackTime / self.player.duration)];
    }
    // 每次更新进度条时，顺便计算并更新一次全屏的 EPG
    [self updateFullscreenEPGOverlay];
    // [新增] 顺便通过1秒定时器实时更新右上角的悬浮系统时间
    [self.controlView updateSystemTime];
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
    
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
    self.isFullscreen = isLandscape;
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:isLandscape withAnimation:UIStatusBarAnimationFade];
    }
    
    // 如果是横屏，立刻推一次 EPG 数据，保证动画期间文本就已经存在
    if (isLandscape) {
        [self updateFullscreenEPGOverlay];
    }
    
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

@end