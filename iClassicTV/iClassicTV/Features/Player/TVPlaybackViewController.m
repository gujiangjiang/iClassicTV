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
#import "ToastHelper.h" // [新增] 引入 ToastHelper
#import <QuartzCore/QuartzCore.h> // [新增] 引入 QuartzCore 用于绘制拟物化边框

@interface TVPlaybackViewController () <TVPlaybackOverlayDelegate, PlayerEPGViewDelegate>

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) TVPlaybackOverlayView *overlayView;

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *epgContainerView; // [新增] EPG 容器，用于承载边框和装饰

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
@property (nonatomic, assign) UIStatusBarStyle originalStatusBarStyle; // [新增] 记录原有的状态栏样式，用于 iOS 6 修复
@property (nonatomic, assign) BOOL hasSavedOriginalNavState;

@end

@implementation TVPlaybackViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
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
    
    // [新增] 初始化 EPG 容器，用于实现 iOS 6 风格的拟物化边框
    self.epgContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.epgContainerView.backgroundColor = [UIColor whiteColor];
    // 模拟 iOS 6 的卡片式阴影
    self.epgContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.epgContainerView.layer.shadowOffset = CGSizeMake(0, -1);
    self.epgContainerView.layer.shadowOpacity = 0.2;
    self.epgContainerView.layer.shadowRadius = 3.0;
    [self.backgroundView addSubview:self.epgContainerView];
    
    self.epgView = [[PlayerEPGView alloc] initWithFrame:CGRectZero];
    self.epgView.channelTitle = self.channelTitle;
    self.epgView.tvgName = self.tvgName;
    self.epgView.delegate = self;
    self.epgView.supportsCatchup = (self.catchupSource && self.catchupSource.length > 0);
    [self.epgContainerView addSubview:self.epgView];
    
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
    // [新增] 监听后台 EPG 数据获取成功的通知自动刷新界面
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(epgDataDidUpdateInBackground) name:@"EPGDataDidUpdateNotification" object:nil];
    
    [self.player play];
    [self startTimer];
    [self updateNowPlayingInfo];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.epgView scrollToCurrentProgram];
    });
}

// [新增] EPG 数据后台刷新完成后的 UI 更新回调
- (void)epgDataDidUpdateInBackground {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.epgView reloadData];
        [self updateFullscreenEPGOverlay];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.epgView reloadData];
    [self updateFullscreenEPGOverlay];
    
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    if (!self.hasSavedOriginalNavState) {
        self.originalBarStyle = self.navigationController.navigationBar.barStyle;
        self.originalTranslucent = self.navigationController.navigationBar.translucent;
        if (!isIOS7) {
            // [新增] 保存原本全局的状态栏样式
            self.originalStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
        }
        self.hasSavedOriginalNavState = YES;
    }
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(orientation);
    
    self.navigationController.navigationBar.translucent = (isLandscape || isIOS7) ? YES : NO;
    
    if (!isIOS7) {
        [[UIApplication sharedApplication] setStatusBarHidden:self.isFullscreen withAnimation:UIStatusBarAnimationNone];
        // [修复] 强制将 iOS 6 的状态栏变为黑色，以防从设置页弹回后依然保持蓝色
        [[UIApplication sharedApplication] setStatusBarStyle:(isLandscape ? UIStatusBarStyleBlackTranslucent : UIStatusBarStyleBlackOpaque) animated:animated];
    }
    
    if (isLandscape) {
        [self.navigationController setNavigationBarHidden:self.isControlsHidden animated:animated];
    } else {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if ([self isMovingFromParentViewController]) {
        [self performCleanupBeforePop];
    }
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    self.navigationController.navigationBar.barStyle = self.originalBarStyle;
    self.navigationController.navigationBar.translucent = self.originalTranslucent;
    
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    if (!isIOS7) {
        // [修复] 退出播放页时，还原 iOS 6 之前的状态栏样式
        [[UIApplication sharedApplication] setStatusBarStyle:self.originalStatusBarStyle animated:animated];
    }
    
    if (![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    }
}

- (void)performCleanupBeforePop {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    
    [self.timer invalidate];
    self.timer = nil;
    [self.overlayView cancelAutoHideTimer];
    
    [self.player stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
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
        
        self.epgContainerView.hidden = YES;
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
        // [优化] 使用经典的 iOS 6 浅灰纹理色作为底层，让纯白的 EPG 区域更有层次感
        self.backgroundView.backgroundColor = isIOS7 ? [UIColor groupTableViewBackgroundColor] : [UIColor scrollViewTexturedBackgroundColor];
        
        CGFloat tableY = CGRectGetMaxY(videoFrame);
        CGFloat tableHeight = self.view.bounds.size.height - tableY;
        
        // [优化] 增加边距，使 EPG 区域看起来像是一个嵌入式的卡片
        CGFloat padding = 10.0;
        self.epgContainerView.frame = CGRectMake(padding, tableY + padding, self.view.bounds.size.width - padding * 2, tableHeight - padding * 2);
        self.epgContainerView.layer.cornerRadius = 8.0;
        self.epgContainerView.layer.masksToBounds = NO; // 允许阴影显示
        self.epgContainerView.hidden = NO;
        
        // EPG 视图填满容器
        self.epgView.frame = self.epgContainerView.bounds;
        self.epgView.layer.cornerRadius = 8.0;
        self.epgView.layer.masksToBounds = YES;
        self.epgView.hidden = NO;
        self.epgView.backgroundColor = [UIColor whiteColor];
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
    // [修改] 将之前阻塞的加载动画改为在后台发起的静默 Toast 提示更新，并在成功后自动刷新列表
    [ToastHelper showToastWithMessage:LocalizedString(@"epg_updating_silently")];
    [[EPGManager sharedManager] fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [ToastHelper showToastWithMessage:LocalizedString(@"epg_update_complete")];
                // 成功后 EPGManager 内部已发出 EPGDataDidUpdateNotification，会自动走重载界面逻辑
            } else {
                [ToastHelper showToastWithMessage:[NSString stringWithFormat:LocalizedString(@"epg_update_failed_msg"), errorMsg]];
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