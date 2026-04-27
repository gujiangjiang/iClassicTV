//
//  TVPlaybackViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController.h"
#import "TVPlaybackViewController+Internal.h"
#import "TVPlaybackViewController+UI.h"
#import "TVPlaybackViewController+Player.h"
#import "TVPlaybackViewController+EPG.h"
#import "LanguageManager.h"
#import "EPGManager.h"
#import "NSString+EncodingHelper.h"
#import <QuartzCore/QuartzCore.h>
#import "WatchListDataManager.h" // [新增] 引入数据管理模块
#import "PlayerConfigManager.h"  // [新增] 判断开关状态

@implementation TVPlaybackViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    // 初始化全屏状态（进入时若是横屏则直接开启全屏模式，但默认不是手动触发）
    self.isFullscreen = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
    self.isManualFullscreen = NO;
    
    // 利用原生特性动态控制视图延伸：全屏时延伸至边缘(All)，非全屏时不延伸(None)以此避开导航栏
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = self.isFullscreen ? UIRectEdgeAll : UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setWantsFullScreenLayout:)]) {
        self.wantsFullScreenLayout = self.isFullscreen;
    }
    
    self.title = self.channelTitle ?: LocalizedString(@"unknown_channel");
    
    // [新增] 进入播放器时，将当前频道数据存入最近播放历史 (底层管理器会进行限制检查)
    NSDictionary *recentInfo = @{
                                 @"name": self.channelTitle ?: @"",
                                 @"url": self.videoURLString ?: @"",
                                 @"tvgName": self.tvgName ?: @"",
                                 @"catchupSource": self.catchupSource ?: @""
                                 };
    [[WatchListDataManager sharedManager] addRecentPlay:recentInfo];
    
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
    
    // 初始化 EPG 容器，用于实现 iOS 6 风格的拟物化边框
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
    // 监听后台 EPG 数据获取成功的通知自动刷新界面
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(epgDataDidUpdateInBackground) name:@"EPGDataDidUpdateNotification" object:nil];
    
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
    
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    if (!self.hasSavedOriginalNavState) {
        self.originalBarStyle = self.navigationController.navigationBar.barStyle;
        self.originalTranslucent = self.navigationController.navigationBar.translucent;
        if (!isIOS7) {
            // 保存原本全局的状态栏样式
            self.originalStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
        }
        self.hasSavedOriginalNavState = YES;
    }
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    // 导航栏的透明度取决于是否在全屏模式，确保全屏下是悬浮的不挤压画面
    self.navigationController.navigationBar.translucent = (self.isFullscreen || isIOS7) ? YES : NO;
    
    if (!isIOS7) {
        BOOL isLocked = self.overlayView.isLocked;
        BOOL shouldHideStatusBar = self.isFullscreen ? (self.isControlsHidden || isLocked) : NO;
        [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationNone];
        // 状态栏的样式取决于是否全屏模式（哪怕是竖屏全屏），全屏必定用悬浮透明的，防止推挤画面
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
    
    // 提前恢复状态栏的显示和样式，并强制重置导航栏的 Y 坐标，防止横屏返回时列表页的标题栏上移被状态栏遮挡
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
    
    // 退出播放时，不再强制写死回到竖屏，而是根据当前手机的真实物理方向旋转
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

- (BOOL)canBecomeFirstResponder { return YES; }

@end