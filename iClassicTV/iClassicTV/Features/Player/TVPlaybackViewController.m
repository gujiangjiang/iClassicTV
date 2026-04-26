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
@property (nonatomic, assign) BOOL isFullscreen; // [说明] 代表当前的“全屏模式状态”
@property (nonatomic, assign) BOOL isManualFullscreen; // [新增] 记录当前全屏是否是由用户点击按钮“手动”触发的
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
    
    // 初始化全屏状态（进入时若是横屏则直接开启全屏模式，但默认不是手动触发）
    self.isFullscreen = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
    self.isManualFullscreen = NO;
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    // [优化] 兼容 iOS 6：允许视图全屏延伸至状态栏和导航栏下方，防止状态栏显隐时挤压画面
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = YES;
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
    
    // [修复] 导航栏的透明度取决于是否在全屏模式，确保全屏下是悬浮的不挤压画面
    self.navigationController.navigationBar.translucent = (self.isFullscreen || isIOS7) ? YES : NO;
    
    if (!isIOS7) {
        BOOL shouldHideStatusBar = self.isFullscreen ? self.isControlsHidden : NO;
        [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationNone];
        // [修复] 状态栏的样式取决于是否全屏模式（哪怕是竖屏全屏），全屏必定用悬浮透明的，防止推挤画面
        [[UIApplication sharedApplication] setStatusBarStyle:(self.isFullscreen ? UIStatusBarStyleBlackTranslucent : UIStatusBarStyleBlackOpaque) animated:animated];
        
        // 统一校准导航栏坐标：如果全屏且隐藏控件，Y为0；否则Y为20
        CGRect navFrame = self.navigationController.navigationBar.frame;
        CGFloat expectedY = shouldHideStatusBar ? 0.0 : 20.0;
        if (navFrame.origin.y != expectedY) {
            navFrame.origin.y = expectedY;
            self.navigationController.navigationBar.frame = navFrame;
        }
    }
    
    BOOL shouldHideNav = self.isFullscreen ? self.isControlsHidden : NO;
    [self.navigationController setNavigationBarHidden:shouldHideNav animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    // [修复] 提前恢复状态栏的显示和样式，并强制重置导航栏的 Y 坐标，防止横屏返回时列表页的标题栏上移被状态栏遮挡
    if (!isIOS7) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
        [[UIApplication sharedApplication] setStatusBarStyle:self.originalStatusBarStyle animated:NO];
        
        CGRect navFrame = self.navigationController.navigationBar.frame;
        if (navFrame.origin.y != 20.0) {
            navFrame.origin.y = 20.0;
            self.navigationController.navigationBar.frame = navFrame;
        }
    }
    
    if ([self isMovingFromParentViewController]) {
        [self performCleanupBeforePop];
    }
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    self.navigationController.navigationBar.barStyle = self.originalBarStyle;
    self.navigationController.navigationBar.translucent = self.originalTranslucent;
    
    if (isIOS7 && ![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
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
    
    // [修复] 退出播放时，不再强制写死回到竖屏，而是根据当前手机的真实物理方向旋转
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    UIInterfaceOrientation targetOrientation;
    if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
        targetOrientation = UIInterfaceOrientationLandscapeRight;
    } else if (deviceOrientation == UIDeviceOrientationLandscapeRight) {
        targetOrientation = UIInterfaceOrientationLandscapeLeft;
    } else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        targetOrientation = UIInterfaceOrientationPortraitUpsideDown;
    } else if (deviceOrientation == UIDeviceOrientationPortrait) {
        targetOrientation = UIInterfaceOrientationPortrait;
    } else {
        // 如果设备平放等无法判断方向，则维持当前状态栏方向
        targetOrientation = [UIApplication sharedApplication].statusBarOrientation;
    }
    
    [self forceRotateToOrientation:targetOrientation];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    [self.overlayView.bottomBar updateFullscreenButtonState:self.isFullscreen];
    
    CGRect videoFrame;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    if (self.isFullscreen) {
        // 全屏模式下，视频区域占满屏幕
        videoFrame = self.view.bounds;
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = [UIColor blackColor];
        
        self.epgContainerView.hidden = YES;
        self.epgView.hidden = YES;
        
    } else {
        // 非全屏模式下，视频固定在上方 16:9 比例
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
    
    // 统一处理 iOS 6 导航栏坐标
    if (!isIOS7 && !self.navigationController.navigationBarHidden) {
        CGRect navFrame = self.navigationController.navigationBar.frame;
        BOOL shouldHideStatusBar = self.isFullscreen ? self.isControlsHidden : NO;
        CGFloat expectedY = shouldHideStatusBar ? 0.0 : 20.0;
        if (navFrame.origin.y != expectedY) {
            navFrame.origin.y = expectedY;
            self.navigationController.navigationBar.frame = navFrame;
        }
    }
    
    self.player.view.frame = videoFrame;
    [self.overlayView updateLayoutForFullscreen:self.isFullscreen videoFrame:videoFrame];
}

#pragma mark - 全屏辅助方法

// 手动更新界面以适配全屏模式的展开或收起（不发生物理设备旋转时调用）
- (void)updateFullscreenUIState {
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    // [修复] 更新全屏状态时，实时将导航栏变为透明悬浮
    self.navigationController.navigationBar.translucent = (self.isFullscreen || isIOS7) ? YES : NO;
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        if (!isIOS7) {
            BOOL shouldHideStatusBar = self.isFullscreen ? self.isControlsHidden : NO;
            [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationFade];
            // [修复] 全屏状态一旦变化，立刻更新状态栏样式为透明悬浮
            [[UIApplication sharedApplication] setStatusBarStyle:(self.isFullscreen ? UIStatusBarStyleBlackTranslucent : UIStatusBarStyleBlackOpaque) animated:YES];
        }
    }
    
    if (self.overlayView.isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        BOOL shouldHideNav = self.isFullscreen ? self.isControlsHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHideNav animated:YES];
    }
    
    // [优化] 动画开始前先将全屏挂件彻底透明隐藏，避免过渡形变期间文字提前突兀出现导致错位
    [self.overlayView.widgetsView setOverlaysHidden:YES];
    
    [UIView animateWithDuration:0.35 animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        // [优化] 动画彻底结束后，如果当前不需要隐藏控制栏，再通过动画平滑淡入这些文字挂件
        if (!self.isControlsHidden) {
            [UIView animateWithDuration:0.25 animations:^{
                [self.overlayView.widgetsView setOverlaysHidden:NO];
            }];
        }
    }];
}

#pragma mark - PlayerEPGViewDelegate

- (void)epgViewDidTapSettings:(PlayerEPGView *)epgView {
    EPGManagerViewController *epgVC = [[EPGManagerViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:epgVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)epgViewDidTapRefresh:(PlayerEPGView *)epgView {
    [ToastHelper showToastWithMessage:LocalizedString(@"epg_updating_silently")];
    [[EPGManager sharedManager] fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [ToastHelper showToastWithMessage:LocalizedString(@"epg_update_complete")];
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
    if (self.isFullscreen) {
        // [新增] 用户主动退出全屏时，清除“手动全屏”记忆标记
        self.isManualFullscreen = NO;
        
        // 如果当前是物理上的横屏，退出全屏必须将其旋转回竖屏
        if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
            // 先标记退出全屏，这样旋转动画开始时，UI 就会提前判定为退出全屏状态
            self.isFullscreen = NO;
            [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
        } else {
            // 如果是竖屏全屏模式，直接修改全屏标记并刷新UI即可
            self.isFullscreen = NO;
            [self updateFullscreenUIState];
        }
    } else {
        // [新增] 准备进入全屏：只要是手动点击进入，就开启“手动全屏”记忆标记
        self.isFullscreen = YES;
        self.isManualFullscreen = YES;
        
        UIInterfaceOrientation target = [PlayerConfigManager preferredInterfaceOrientation];
        
        if (UIInterfaceOrientationIsLandscape(target)) {
            // 设置项要求横屏：如果在竖屏则强制旋转，如果在横屏则直接刷新界面
            if (!UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
                [self forceRotateToOrientation:target];
            } else {
                [self updateFullscreenUIState];
            }
        } else {
            // 设置项要求竖屏，或者跟随系统：直接在当前方向上进入全屏界面模式（不强制旋转设备）
            [self updateFullscreenUIState];
        }
    }
}

- (void)overlaySliderValueChanged:(float)value {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = value * self.player.duration;
    }
}

- (void)overlayControlsHiddenDidChange:(BOOL)isHidden {
    self.isControlsHidden = isHidden;
    
    // 无论是竖向全屏还是横向全屏，只要是在全屏模式，控件显隐就决定状态栏的显隐
    BOOL shouldHideStatusBar = self.isFullscreen ? isHidden : NO;
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationFade];
    }
    
    if (self.overlayView.isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        BOOL shouldHideNav = self.isFullscreen ? isHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHideNav animated:YES];
        
        // 手动调整 iOS 6 下导航条出现时的 Y 轴偏移，防止被悬浮的半透明状态栏遮盖
        if (![[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0 && !shouldHideNav) {
            CGRect navFrame = self.navigationController.navigationBar.frame;
            CGFloat expectedY = shouldHideStatusBar ? 0.0 : 20.0;
            if (navFrame.origin.y != expectedY) {
                navFrame.origin.y = expectedY;
                self.navigationController.navigationBar.frame = navFrame;
            }
        }
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
    // 无论竖向全屏还是横向全屏，只要在全屏模式，就根据控件显隐来控制状态栏
    return self.isFullscreen ? self.isControlsHidden : NO;
}

- (BOOL)shouldAutorotate { return YES; }

- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAllButUpsideDown; }

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    if (!isIOS7) {
        BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
        
        // [修复] 旋转即将发生时，即将变成全屏的条件：要么转到横屏必然全屏，要么当前已经处于“手动全屏”且即将转到竖屏
        BOOL isGoingFullscreen = isLandscape || self.isManualFullscreen;
        BOOL shouldHideStatusBar = isGoingFullscreen ? self.isControlsHidden : NO;
        
        [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationNone];
        // 旋转前确保如果即将变成全屏，则采用透明悬浮样式
        [[UIApplication sharedApplication] setStatusBarStyle:(isGoingFullscreen ? UIStatusBarStyleBlackTranslucent : UIStatusBarStyleBlackOpaque) animated:NO];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
    
    // [修复] 用户物理旋转了设备核心逻辑：
    // 如果转到横屏，必定是全屏。
    // 如果转到竖屏，只有在用户开启了“手动全屏”记忆的状态下才保持全屏，否则自动退出全屏。
    if (isLandscape) {
        self.isFullscreen = YES;
    } else {
        self.isFullscreen = self.isManualFullscreen;
    }
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    // 导航栏的透明度跟随最终确认的全屏状态
    self.navigationController.navigationBar.translucent = (self.isFullscreen || isIOS7) ? YES : NO;
    
    if (self.overlayView.isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        BOOL shouldHide = self.isFullscreen ? self.isControlsHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHide animated:YES];
    }
    
    // [优化] 动画开始前先将全屏挂件彻底透明隐藏，避免过渡形变期间文字提前突兀出现导致错位
    [self.overlayView.widgetsView setOverlaysHidden:YES];
    
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        // [优化] 动画彻底结束后，如果当前不需要隐藏控制栏，再通过动画平滑淡入这些文字挂件
        if (!self.isControlsHidden) {
            [UIView animateWithDuration:0.25 animations:^{
                [self.overlayView.widgetsView setOverlaysHidden:NO];
            }];
        }
    }];
}

@end