//
//  PlayerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface PlayerViewController ()
@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) UIView *gestureCatcherView;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UISlider *progressBar;
@property (nonatomic, strong) UIButton *fullBtn;
@property (nonatomic, strong) UILabel *statusLabel; // 新增：播放状态及纯音频反馈层

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *autoHideTimer;

@property (nonatomic, assign) BOOL isControlsHidden;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) UIInterfaceOrientation originalOrientation;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    self.isFullscreen = NO;
    self.originalOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // 1. 初始化 iOS 原生解码内核播放器
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.view.frame = self.view.bounds;
    self.player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.player.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:self.player.view];
    
    // 1.5 状态反馈提示层 (放在视频之上，手势拦截层之下)
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 100)];
    self.statusLabel.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.text = @"加载中...";
    [self.view addSubview:self.statusLabel];
    
    // 1.6 手势拦截层
    self.gestureCatcherView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.gestureCatcherView.backgroundColor = [UIColor clearColor];
    self.gestureCatcherView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.gestureCatcherView];
    
    // 2. 顶部导航栏
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.topBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    self.topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.topBar];
    
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(5, 0, 60, 44);
    [backBtn setTitle:@"< 返回" forState:UIControlStateNormal];
    [backBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [backBtn addTarget:self action:@selector(closePlayer) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:backBtn];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, self.view.bounds.size.width - 140, 44)];
    titleLabel.text = self.channelTitle;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topBar addSubview:titleLabel];
    
    // 3. 底部控制栏
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 50, self.view.bounds.size.width, 50)];
    self.bottomBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.bottomBar];
    
    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake(5, 5, 50, 40);
    [self.playBtn setTitle:@"暂停" forState:UIControlStateNormal];
    [self.playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.playBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.playBtn addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.playBtn];
    
    self.progressBar = [[UISlider alloc] initWithFrame:CGRectMake(60, 10, self.view.bounds.size.width - 155, 30)];
    self.progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.progressBar addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressBar addTarget:self action:@selector(cancelAutoHideTimer) forControlEvents:UIControlEventTouchDown];
    [self.progressBar addTarget:self action:@selector(startAutoHideTimer) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.bottomBar addSubview:self.progressBar];
    
    self.fullBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullBtn.frame = CGRectMake(self.view.bounds.size.width - 85, 5, 80, 40);
    [self.fullBtn setTitle:@"全屏" forState:UIControlStateNormal];
    [self.fullBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fullBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    self.fullBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.fullBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.fullBtn addTarget:self action:@selector(toggleFullscreenAction) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.fullBtn];
    
    // 4. 添加手势控制
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.gestureCatcherView addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.gestureCatcherView addGestureRecognizer:singleTap];
    
    // 5. 监听播放与缓冲状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadStateChanged) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaTypesAvailable) name:MPMovieMediaTypesAvailableNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    [self.player play];
    [self startTimer];
    
    [self startAutoHideTimer];
}

#pragma mark - 新增：播放状态与智能类型反馈逻辑

- (void)loadStateChanged {
    if (self.player.loadState & MPMovieLoadStateStalled) {
        // 如果已经在显示错误或者音频，不要被“缓冲中”覆盖
        // 修复：iOS 6 不支持 containsString:，替换为 rangeOfString:
        if ([self.statusLabel.text rangeOfString:@"📻"].location == NSNotFound &&
            [self.statusLabel.text rangeOfString:@"❌"].location == NSNotFound) {
            self.statusLabel.text = @"缓冲中...";
            self.statusLabel.hidden = NO;
        }
    } else if ((self.player.loadState & MPMovieLoadStatePlayable) || (self.player.loadState & MPMovieLoadStatePlaythroughOK)) {
        // 数据可播放，判断是否有视频轨道
        if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 &&
            (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
            self.statusLabel.text = @"📻\n\n电台或纯音频源 / 无画面信号";
            self.statusLabel.hidden = NO;
        } else {
            self.statusLabel.hidden = YES; // 有画面，隐藏提示，露出视频
        }
    }
}

- (void)mediaTypesAvailable {
    // 获取到流媒体类型时进行精确判断，只有音频没有视频时
    if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 &&
        (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
        self.statusLabel.text = @"📻\n\n电台或纯音频源 / 无画面信号";
        self.statusLabel.hidden = NO;
    } else if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) != 0) {
        // 如果确实有画面，且目前缓冲充足，则隐藏提示
        if (self.player.loadState & MPMovieLoadStatePlayable || self.player.loadState & MPMovieLoadStatePlaythroughOK) {
            self.statusLabel.hidden = YES;
        }
    }
}

- (void)playbackDidFinish:(NSNotification *)notification {
    NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if (reason != nil && [reason integerValue] == MPMovieFinishReasonPlaybackError) {
        // 遇到彻底解析失败、无网络、或者完全无法解码的源时，拦截并提示
        self.statusLabel.text = @"❌\n\n播放失败或设备不支持该视频格式";
        self.statusLabel.hidden = NO;
    }
}

#pragma mark - 5秒自动隐藏控件逻辑

- (void)startAutoHideTimer {
    [self cancelAutoHideTimer];
    self.autoHideTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(autoHideControls) userInfo:nil repeats:NO];
}

- (void)cancelAutoHideTimer {
    if (self.autoHideTimer) {
        [self.autoHideTimer invalidate];
        self.autoHideTimer = nil;
    }
}

- (void)autoHideControls {
    if (!self.isControlsHidden) {
        [self setControlsHidden:YES];
    }
}

- (void)setControlsHidden:(BOOL)hidden {
    if (self.isControlsHidden == hidden) return;
    self.isControlsHidden = hidden;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.topBar.alpha = self.isControlsHidden ? 0.0 : 1.0;
        self.bottomBar.alpha = self.isControlsHidden ? 0.0 : 1.0;
    }];
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:self.isControlsHidden withAnimation:UIStatusBarAnimationFade];
    }
    
    if (!hidden) {
        [self startAutoHideTimer];
    } else {
        [self cancelAutoHideTimer];
    }
}

#pragma mark - 交互逻辑

- (void)handleSingleTap:(UITapGestureRecognizer *)sender {
    [self setControlsHidden:!self.isControlsHidden];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)sender {
    [self toggleFullscreenAction];
}

- (void)toggleFullscreenAction {
    [self startAutoHideTimer];
    
    if (self.isFullscreen) {
        self.isFullscreen = NO;
        [self.fullBtn setTitle:@"全屏" forState:UIControlStateNormal];
        [self forceRotateToOrientation:self.originalOrientation];
    } else {
        self.isFullscreen = YES;
        [self.fullBtn setTitle:@"退出全屏" forState:UIControlStateNormal];
        
        self.originalOrientation = [UIApplication sharedApplication].statusBarOrientation;
        
        NSInteger orientationPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        UIInterfaceOrientation targetOrientation = UIInterfaceOrientationLandscapeRight;
        
        if (orientationPref == 1) {
            targetOrientation = UIInterfaceOrientationLandscapeRight;
        } else if (orientationPref == 2) {
            targetOrientation = UIInterfaceOrientationPortrait;
        } else {
            targetOrientation = UIInterfaceOrientationLandscapeRight;
        }
        
        [self forceRotateToOrientation:targetOrientation];
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

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)updateProgress {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.progressBar.value = self.player.currentPlaybackTime / self.player.duration;
    }
}

- (void)sliderValueChanged:(UISlider *)slider {
    [self startAutoHideTimer];
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = slider.value * self.player.duration;
    }
}

- (void)togglePlay {
    [self startAutoHideTimer];
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        [self.player pause];
    } else {
        [self.player play];
    }
}

- (void)playbackStateChanged {
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        [self.playBtn setTitle:@"暂停" forState:UIControlStateNormal];
    } else {
        [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
    }
}

- (BOOL)prefersStatusBarHidden {
    return self.isControlsHidden;
}

- (void)closePlayer {
    [self cancelAutoHideTimer];
    
    if (![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    }
    
    [self.timer invalidate];
    self.timer = nil;
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