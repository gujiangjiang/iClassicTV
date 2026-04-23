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
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UISlider *progressBar;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isControlsHidden;
@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    // 1. 初始化 iOS 原生解码内核播放器
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.view.frame = self.view.bounds;
    self.player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    // 【核心修正】：永远保持 None，拒绝系统UI的介入
    self.player.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:self.player.view];
    
    // 2. 顶部导航栏 (包含返回按钮和频道名称)
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.topBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7]; // 半透明纯黑底色
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
    
    // 3. 底部控制栏 (包含播放/暂停、进度条、全屏按钮)
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
    
    self.progressBar = [[UISlider alloc] initWithFrame:CGRectMake(60, 10, self.view.bounds.size.width - 125, 30)];
    self.progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.progressBar addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.bottomBar addSubview:self.progressBar];
    
    UIButton *fullBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    fullBtn.frame = CGRectMake(self.view.bounds.size.width - 60, 5, 50, 40);
    [fullBtn setTitle:@"全屏" forState:UIControlStateNormal];
    [fullBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    fullBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    fullBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [fullBtn addTarget:self action:@selector(toggleFullscreen) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:fullBtn];
    
    // 4. 【新增】添加手势控制：双击全屏 与 单击隐藏/显示控件
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleFullscreen)];
    doubleTap.numberOfTapsRequired = 2; // 双击触发全屏
    [self.view addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControls)];
    singleTap.numberOfTapsRequired = 1; // 单击触发隐藏/显示
    // 【关键】：告诉系统必须等待双击判定失败后，才执行单击。防止单击和双击事件打架。
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.view addGestureRecognizer:singleTap];
    
    // 5. 监听播放状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    
    [self.player play];
    [self startTimer];
}

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

- (void)updateProgress {
    // 针对直播源的特殊保护：直播源可能没有时长 (duration 为 0 或 NaN)
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.progressBar.value = self.player.currentPlaybackTime / self.player.duration;
    }
}

- (void)sliderValueChanged:(UISlider *)slider {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = slider.value * self.player.duration;
    }
}

- (void)togglePlay {
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

- (void)toggleFullscreen {
    // 读取用户在设置中设定的全屏逻辑偏好
    NSInteger orientationPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
    
    UIInterfaceOrientation targetOrientation = UIInterfaceOrientationLandscapeRight;
    
    if (orientationPref == 1) {
        targetOrientation = UIInterfaceOrientationLandscapeRight; // 强制横屏
    } else if (orientationPref == 2) {
        targetOrientation = UIInterfaceOrientationPortrait; // 强制竖屏
    } else {
        // 0 = 跟随系统。如果当前是竖屏，点击全屏进入横屏；反之退回竖屏（充当开关）
        UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UIInterfaceOrientationIsPortrait(currentOrientation)) {
            targetOrientation = UIInterfaceOrientationLandscapeRight;
        } else {
            targetOrientation = UIInterfaceOrientationPortrait;
        }
    }
    
    // 【核心修改】：利用底层 API 强制向系统发送设备方向变更的通知。
    // 我们不再调用 [self.player setFullscreen:YES]，这样就彻底避免了进入系统默认黑盒子 UI，
    // 原生的画面会自动跟随设备方向填满屏幕，同时完美保留我们的自定义组件！
    
    // Hack: 先设为 Unknown 保证系统一定会刷新布局
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationUnknown] forKey:@"orientation"];
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:targetOrientation] forKey:@"orientation"];
}

- (void)toggleControls {
    self.isControlsHidden = !self.isControlsHidden;
    [UIView animateWithDuration:0.3 animations:^{
        self.topBar.alpha = self.isControlsHidden ? 0.0 : 1.0;
        self.bottomBar.alpha = self.isControlsHidden ? 0.0 : 1.0;
    }];
    
    // 沉浸式体验：隐藏控制栏时，连带隐藏系统顶部的状态栏 (时间、电池等)
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        // 适配 iOS 7 及以上
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        // 适配 iOS 6
        [[UIApplication sharedApplication] setStatusBarHidden:self.isControlsHidden withAnimation:UIStatusBarAnimationFade];
    }
}

// 供 iOS 7+ 系统调用，决定是否隐藏状态栏
- (BOOL)prefersStatusBarHidden {
    return self.isControlsHidden;
}

- (void)closePlayer {
    // 退出播放器时，确保恢复系统状态栏显示
    if (![self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    }
    
    [self.timer invalidate];
    self.timer = nil;
    [self.player stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 允许该播放器页面支持横竖屏自动旋转
- (BOOL)shouldAutorotate {
    return YES;
}
- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end