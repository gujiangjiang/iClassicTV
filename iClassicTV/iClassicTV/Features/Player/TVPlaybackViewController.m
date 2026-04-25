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
#import "NSString+EncodingHelper.h"

@interface TVPlaybackViewController () <TVPlaybackOverlayDelegate, PlayerEPGViewDelegate>

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) TVPlaybackOverlayView *overlayView;

@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;

@property (nonatomic, strong) PlayerEPGView *epgView;
@property (nonatomic, strong) NSDateFormatter *epgTimeFormatter;
@property (nonatomic, strong) NSDateFormatter *catchupTimeFormatter;
@property (nonatomic, strong) NSDateFormatter *displayTimeFormatter;

@property (nonatomic, strong) EPGProgram *replayingProgram;

@property (nonatomic, assign) UIBarStyle originalBarStyle;
@property (nonatomic, assign) BOOL originalTranslucent;
@property (nonatomic, assign) BOOL hasSavedOriginalNavState;

@end

@implementation TVPlaybackViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    // [修复] 移除手动创建的左侧按钮，交还给系统接管，这样原生的带有箭头的 back 按钮就会恢复显示
    self.title = self.channelTitle ?: LocalizedString(@"unknown_channel");
    
    self.epgTimeFormatter = [[NSDateFormatter alloc] init];
    [self.epgTimeFormatter setTimeZone:[EPGManager sharedManager].epgTimeZone];
    [self.epgTimeFormatter setDateFormat:@"HH:mm"];
    
    self.catchupTimeFormatter = [[NSDateFormatter alloc] init];
    [self.catchupTimeFormatter setTimeZone:[EPGManager sharedManager].epgTimeZone];
    [self.catchupTimeFormatter setDateFormat:@"yyyyMMddHHmmss"];
    
    self.displayTimeFormatter = [[NSDateFormatter alloc] init];
    [self.displayTimeFormatter setTimeZone:[EPGManager sharedManager].epgTimeZone];
    [self.displayTimeFormatter setDateFormat:@"MM-dd HH:mm"];
    
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
    
    NSURL *url = [self.videoURLString toSafeURL];
    
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:self.player.view];
    
    self.overlayView = [[TVPlaybackOverlayView alloc] initWithFrame:self.view.bounds];
    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayView.delegate = self;
    [self.view addSubview:self.overlayView];
    
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
    
    if (!self.hasSavedOriginalNavState) {
        self.originalBarStyle = self.navigationController.navigationBar.barStyle;
        self.originalTranslucent = self.navigationController.navigationBar.translucent;
        self.hasSavedOriginalNavState = YES;
    }
    
    // [优化] 采纳建议：在播放器页面中，无论是横屏还是竖屏，统一强制使用黑色的沉浸式导航栏
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
    
    // iOS6 下竖屏为了避免遮挡保留不透明，横屏半透明；iOS7 统一半透明
    self.navigationController.navigationBar.translucent = (isLandscape || isIOS7) ? YES : NO;
    
    if (isLandscape) {
        [self.navigationController setNavigationBarHidden:self.isControlsHidden animated:animated];
    } else {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // [修复] 监听系统的返回事件。当用户点击原生左上角返回（导致当前页面即将被移出父控制器）时执行资源清理
    if ([self isMovingFromParentViewController]) {
        [self performCleanupBeforePop];
    }
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    self.navigationController.navigationBar.barStyle = self.originalBarStyle;
    self.navigationController.navigationBar.translucent = self.originalTranslucent;
    
    if (![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
}

// [修复] 专门用于退出前的资源清理和强制竖屏的方法，替代之前的 closePlayer
- (void)performCleanupBeforePop {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    
    [self.timer invalidate];
    self.timer = nil;
    [self.overlayView cancelAutoHideTimer];
    
    [self.player stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // 强制切回竖屏，以免造成上一个页面横屏布局错乱
    [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
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
        
        if (!isIOS7 && !self.navigationController.navigationBarHidden) {
            CGRect navFrame = self.navigationController.navigationBar.frame;
            if (navFrame.origin.y != 0) {
                navFrame.origin.y = 0;
                self.navigationController.navigationBar.frame = navFrame;
            }
        }
    } else {
        videoFrame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width * 9.0 / 16.0);
        
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = isIOS7 ? [UIColor groupTableViewBackgroundColor] : [UIColor scrollViewTexturedBackgroundColor];
        
        CGFloat tableY = CGRectGetMaxY(videoFrame);
        CGFloat tableHeight = self.view.bounds.size.height - tableY;
        self.epgView.frame = CGRectMake(0, tableY, self.view.bounds.size.width, tableHeight);
        self.epgView.hidden = NO;
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
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"refresh_failed_title") message:errorMsg delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
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
        
        NSURL *url = [self.videoURLString toSafeURL];
        
        [self.player setContentURL:url];
        [self.player play];
        
        [self.overlayView showStatusMessage:[NSString stringWithFormat:LocalizedString(@"returned_to_live_format"), program.title]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.overlayView hideStatusMessage];
        });
        
        [self updateFullscreenEPGOverlay];
        return;
    }
    
    self.replayingProgram = program;
    self.epgView.replayingProgram = program;
    self.overlayView.widgetsView.isCatchupMode = YES;
    
    NSString *bTime = [self.catchupTimeFormatter stringFromDate:program.startTime];
    NSString *eTime = [self.catchupTimeFormatter stringFromDate:program.endTime];
    
    NSString *catchupParams = self.catchupSource;
    catchupParams = [catchupParams stringByReplacingOccurrencesOfString:@"${(b)yyyyMMddHHmmss}" withString:bTime];
    catchupParams = [catchupParams stringByReplacingOccurrencesOfString:@"${(e)yyyyMMddHHmmss}" withString:eTime];
    
    NSString *finalURLStr = self.videoURLString;
    if ([catchupParams hasPrefix:@"http://"] || [catchupParams hasPrefix:@"https://"]) {
        finalURLStr = catchupParams;
    } else {
        finalURLStr = [finalURLStr stringByAppendingString:catchupParams];
    }
    
    NSURL *url = [finalURLStr toSafeURL];
    
    [self.player setContentURL:url];
    [self.player play];
    
    NSString *displayTime = [self.displayTimeFormatter stringFromDate:program.startTime];
    
    [self.overlayView showStatusMessage:[NSString stringWithFormat:LocalizedString(@"replaying_time_format"), displayTime, program.title]];
    
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
        NSString *line1 = [NSString stringWithFormat:LocalizedString(@"replaying_colon_format"), [self.epgTimeFormatter stringFromDate:self.replayingProgram.startTime], self.replayingProgram.title];
        NSString *line2 = current ? [NSString stringWithFormat:LocalizedString(@"live_colon_format"), [self.epgTimeFormatter stringFromDate:current.startTime], current.title] : LocalizedString(@"live_no_data");
        [self.overlayView.widgetsView updateCurrentProgram:line1 nextProgram:line2];
    } else {
        EPGProgram *next = [self.epgView nextPlayingProgram];
        if (!current && !next) {
            [self.overlayView.widgetsView updateCurrentProgram:nil nextProgram:nil];
            return;
        }
        
        NSString *currentStr = current ? [NSString stringWithFormat:LocalizedString(@"playing_colon_format"), [self.epgTimeFormatter stringFromDate:current.startTime], current.title] : LocalizedString(@"playing_no_data");
        NSString *nextStr = next ? [NSString stringWithFormat:LocalizedString(@"next_colon_format"), [self.epgTimeFormatter stringFromDate:next.startTime], next.title] : LocalizedString(@"next_no_data");
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
    
    if (self.overlayView.isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        BOOL shouldHide = self.isFullscreen ? isHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHide animated:YES];
    }
    
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
    [self.epgView updateTimeTick];
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

- (BOOL)shouldAutorotate { return YES; }

- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAllButUpsideDown; }

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    if (!isIOS7) {
        BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
        [[UIApplication sharedApplication] setStatusBarHidden:isLandscape withAnimation:UIStatusBarAnimationNone];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
    self.isFullscreen = isLandscape;
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
    
    // [优化] 无论全屏还是竖屏，始终保持黑色的沉浸式体验
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    self.navigationController.navigationBar.translucent = (isLandscape || isIOS7) ? YES : NO;
    
    if (self.overlayView.isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        BOOL shouldHide = isLandscape ? self.isControlsHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHide animated:YES];
    }
    
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

@end