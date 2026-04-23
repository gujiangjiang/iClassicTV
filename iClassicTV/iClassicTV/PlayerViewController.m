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

@property (nonatomic, strong) NSTimer *timer; // 用于更新进度条
@property (nonatomic, strong) NSTimer *autoHideTimer; // 新增：用于5秒自动隐藏控件的计时器

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
    
    // 1.5 手势拦截层
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
    
    // 【修复】：缩小进度条宽度（从 125 缩小为 155），给右侧全屏按钮留出足够空间
    self.progressBar = [[UISlider alloc] initWithFrame:CGRectMake(60, 10, self.view.bounds.size.width - 155, 30)];
    self.progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.progressBar addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    // 【新增】：拖动进度条时暂停自动隐藏，松开手时再重新开始倒计时
    [self.progressBar addTarget:self action:@selector(cancelAutoHideTimer) forControlEvents:UIControlEventTouchDown];
    [self.progressBar addTarget:self action:@selector(startAutoHideTimer) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.bottomBar addSubview:self.progressBar];
    
    // 【修复】：将按钮宽度从 50 加宽至 80，解决文字截断问题
    self.fullBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullBtn.frame = CGRectMake(self.view.bounds.size.width - 85, 5, 80, 40);
    [self.fullBtn setTitle:@"全屏" forState:UIControlStateNormal];
    [self.fullBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fullBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    self.fullBtn.titleLabel.adjustsFontSizeToFitWidth = YES; // 开启字体自适应缩小保底
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
    
    // 5. 监听播放状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    
    [self.player play];
    [self startTimer];
    
    // 初始状态下启动自动隐藏倒计时
    [self startAutoHideTimer];
}

#pragma mark - 新增：5秒自动隐藏控件逻辑

- (void)startAutoHideTimer {
    [self cancelAutoHideTimer];
    // 设置 5 秒后执行隐藏动作
    self.autoHideTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(autoHideControls) userInfo:nil repeats:NO];
}

- (void)cancelAutoHideTimer {
    if (self.autoHideTimer) {
        [self.autoHideTimer invalidate];
        self.autoHideTimer = nil;
    }
}

- (void)autoHideControls {
    // 只有在控件当前处于显示状态时才执行隐藏
    if (!self.isControlsHidden) {
        [self setControlsHidden:YES];
    }
}

// 提取出统一的控件显隐控制方法
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
        [self startAutoHideTimer]; // 如果切换为显示，重新开始 5 秒倒计时
    } else {
        [self cancelAutoHideTimer]; // 如果已隐藏，则取消倒计时
    }
}

#pragma mark - 交互逻辑

- (void)handleSingleTap:(UITapGestureRecognizer *)sender {
    [self setControlsHidden:!self.isControlsHidden]; // 触发显隐切换
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)sender {
    [self toggleFullscreenAction];
}

- (void)toggleFullscreenAction {
    [self startAutoHideTimer]; // 用户操作后重置倒计时
    
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
    [self startAutoHideTimer]; // 用户操作后重置倒计时
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = slider.value * self.player.duration;
    }
}

- (void)togglePlay {
    [self startAutoHideTimer]; // 用户操作后重置倒计时
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
    [self cancelAutoHideTimer]; // 退出时清理倒计时
    
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