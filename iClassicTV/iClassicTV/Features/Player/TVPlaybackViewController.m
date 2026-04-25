//
//  TVPlaybackViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "PlayerConfigManager.h"
#import "TVPlaybackOverlayView.h"
#import "LanguageManager.h"
#import "PlayerEPGView.h"
#import "EPGManager.h"
#import "EPGProgram.h"
#import "EPGManagerViewController.h"

@interface TVPlaybackViewController () <TVPlaybackOverlayDelegate, PlayerEPGViewDelegate>

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) TVPlaybackOverlayView *overlayView;

@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;

@property (nonatomic, strong) PlayerEPGView *epgView;
@property (nonatomic, strong) NSDateFormatter *epgTimeFormatter;

// 内部持有一个回放的标识，用于动态管控切流状态与 UI 层级
@property (nonatomic, strong) EPGProgram *replayingProgram;

@end

@implementation TVPlaybackViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    self.epgTimeFormatter = [[NSDateFormatter alloc] init];
    [self.epgTimeFormatter setDateFormat:@"HH:mm"];
    
    self.backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.backgroundView];
    
    self.epgView = [[PlayerEPGView alloc] initWithFrame:CGRectZero];
    self.epgView.channelTitle = self.channelTitle;
    self.epgView.tvgName = self.tvgName;
    self.epgView.delegate = self;
    self.epgView.supportsCatchup = (self.catchupSource && self.catchupSource.length > 0);
    [self.view addSubview:self.epgView];
    
    [self.epgView reloadData];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:self.player.view];
    
    self.overlayView = [[TVPlaybackOverlayView alloc] initWithFrame:self.view.bounds];
    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayView.delegate = self;
    [self.view addSubview:self.overlayView];
    
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.epgView reloadData];
    [self updateFullscreenEPGOverlay];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    self.isFullscreen = UIInterfaceOrientationIsLandscape(orientation);
    
    [self.overlayView.bottomBar updateFullscreenButtonState:self.isFullscreen];
    
    CGRect videoFrame;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    if (self.isFullscreen) {
        videoFrame = self.view.bounds;
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = [UIColor blackColor];
        
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
    
    if (self.overlayView.isLocked) {
        self.navBar.alpha = 0.0;
    } else {
        self.navBar.alpha = (!self.isFullscreen) ? 1.0 : (self.isControlsHidden ? 0.0 : 1.0);
    }
    
    self.player.view.frame = videoFrame;
    [self.overlayView updateLayoutForFullscreen:self.isFullscreen videoFrame:videoFrame];
}

#pragma mark - PlayerEPGViewDelegate

- (void)epgViewDidTapSettings:(PlayerEPGView *)epgView {
    EPGManagerViewController *epgVC = [[EPGManagerViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:epgVC];
    [self presentViewController:nav animated:YES completion:nil];
}

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

- (void)epgView:(PlayerEPGView *)epgView didSelectProgram:(EPGProgram *)program {
    if (self.catchupSource.length == 0) return;
    
    NSDate *now = [NSDate date];
    
    if ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending) {
        self.replayingProgram = nil;
        self.epgView.replayingProgram = nil;
        self.overlayView.widgetsView.isCatchupMode = NO;
        
        NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        [self.player setContentURL:url];
        [self.player play];
        
        [self.overlayView showStatusMessage:[NSString stringWithFormat:@"已回到直播: %@", program.title]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.overlayView hideStatusMessage];
        });
        
        [self updateFullscreenEPGOverlay];
        return;
    }
    
    self.replayingProgram = program;
    self.epgView.replayingProgram = program;
    self.overlayView.widgetsView.isCatchupMode = YES;
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyyMMddHHmmss"];
    NSString *bTime = [df stringFromDate:program.startTime];
    NSString *eTime = [df stringFromDate:program.endTime];
    
    NSString *catchupParams = self.catchupSource;
    catchupParams = [catchupParams stringByReplacingOccurrencesOfString:@"${(b)yyyyMMddHHmmss}" withString:bTime];
    catchupParams = [catchupParams stringByReplacingOccurrencesOfString:@"${(e)yyyyMMddHHmmss}" withString:eTime];
    
    NSString *finalURLStr = self.videoURLString;
    if ([catchupParams hasPrefix:@"http://"] || [catchupParams hasPrefix:@"https://"]) {
        finalURLStr = catchupParams;
    } else {
        finalURLStr = [finalURLStr stringByAppendingString:catchupParams];
    }
    
    NSURL *url = [NSURL URLWithString:[finalURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [self.player setContentURL:url];
    [self.player play];
    
    // 补全提示文字：拼出完整的 日期 时间 格式
    NSDateFormatter *displayDf = [[NSDateFormatter alloc] init];
    [displayDf setDateFormat:@"MM-dd HH:mm"];
    NSString *displayTime = [displayDf stringFromDate:program.startTime];
    
    [self.overlayView showStatusMessage:[NSString stringWithFormat:@"正在回放: %@ %@", displayTime, program.title]];
    
    // 设置三秒后自动隐藏（如果底层播放器立刻缓冲完毕，也会自动接管并隐藏提示，完全符合您的期待逻辑）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.overlayView hideStatusMessage];
    });
    
    [self updateFullscreenEPGOverlay];
}

- (void)updateFullscreenEPGOverlay {
    if (![EPGManager sharedManager].isEPGEnabled || !self.isFullscreen) {
        return;
    }
    
    EPGProgram *current = [self.epgView currentPlayingProgram];
    
    if (self.replayingProgram) {
        NSString *line1 = [NSString stringWithFormat:@"%@ 正在回放：%@", [self.epgTimeFormatter stringFromDate:self.replayingProgram.startTime], self.replayingProgram.title];
        NSString *line2 = current ? [NSString stringWithFormat:@"%@ 正在直播：%@", [self.epgTimeFormatter stringFromDate:current.startTime], current.title] : @"正在直播：暂无节目数据";
        [self.overlayView.widgetsView updateCurrentProgram:line1 nextProgram:line2];
    } else {
        EPGProgram *next = [self.epgView nextPlayingProgram];
        if (!current && !next) {
            [self.overlayView.widgetsView updateCurrentProgram:nil nextProgram:nil];
            return;
        }
        
        NSString *currentStr = current ? [NSString stringWithFormat:@"%@ 正在播放：%@", [self.epgTimeFormatter stringFromDate:current.startTime], current.title] : @"正在播放：暂无节目数据";
        NSString *nextStr = next ? [NSString stringWithFormat:@"%@ 即将播放：%@", [self.epgTimeFormatter stringFromDate:next.startTime], next.title] : @"即将播放：暂无节目数据";
        [self.overlayView.widgetsView updateCurrentProgram:currentStr nextProgram:nextStr];
    }
}

#pragma mark - TVPlaybackOverlayDelegate

- (void)overlayDidTapPlayPause {
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) [self.player pause];
    else [self.player play];
}

- (void)overlayDidTapFullscreen {
    if (self.isFullscreen) [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
    else {
        UIInterfaceOrientation target = [PlayerConfigManager preferredInterfaceOrientation];
        if (!UIInterfaceOrientationIsLandscape(target)) target = UIInterfaceOrientationLandscapeRight;
        [self forceRotateToOrientation:target];
    }
}

- (void)overlaySliderValueChanged:(float)value {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = value * self.player.duration;
    }
}

- (void)overlayControlsHiddenDidChange:(BOOL)isHidden {
    self.isControlsHidden = isHidden;
    
    [UIView animateWithDuration:0.3 animations:^{
        if (self.overlayView.isLocked) {
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
    if (self.player.loadState & MPMovieLoadStateStalled) [self.overlayView showStatusMessage:LocalizedString(@"buffering")];
    else if ((self.player.loadState & MPMovieLoadStatePlayable) || (self.player.loadState & MPMovieLoadStatePlaythroughOK)) {
        if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
            [self.overlayView showStatusMessage:LocalizedString(@"audio_only_signal")];
        } else [self.overlayView hideStatusMessage];
    }
}

- (void)mediaTypesAvailable {
    if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
        [self.overlayView showStatusMessage:LocalizedString(@"audio_only_signal")];
    } else if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) != 0) {
        if (self.player.loadState & MPMovieLoadStatePlayable || self.player.loadState & MPMovieLoadStatePlaythroughOK) {
            [self.overlayView hideStatusMessage];
        }
    }
}

- (void)playbackStateChanged {
    [self.overlayView.bottomBar updatePlayButtonState:(self.player.playbackState == MPMoviePlaybackStatePlaying)];
}

- (void)playbackDidFinish:(NSNotification *)notification {
    NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if (reason != nil && [reason integerValue] == MPMovieFinishReasonPlaybackError) {
        [self.overlayView showStatusMessage:LocalizedString(@"playback_failed")];
    }
}

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)updateProgress {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        [self.overlayView.bottomBar updateProgressWithValue:(self.player.currentPlaybackTime / self.player.duration)];
    }
    [self updateFullscreenEPGOverlay];
    [self.overlayView.widgetsView updateSystemTime];
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
    [self.overlayView cancelAutoHideTimer];
    
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
    
    if (isLandscape) {
        [self updateFullscreenEPGOverlay];
    }
    
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

@end