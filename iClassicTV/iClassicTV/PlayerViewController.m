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
    self.player.controlStyle = MPMovieControlStyleNone; // 隐藏 iOS 默认控制条，使用我们的外观组件
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
    
    // 4. 添加手势控制：点击屏幕任意位置显示/隐藏 UI 控制栏
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControls)];
    [self.view addGestureRecognizer:tap];
    
    // 5. 监听播放状态和退出全屏事件
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exitFullscreen) name:MPMoviePlayerWillExitFullscreenNotification object:self.player];
    
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
    
    // 利用底层 API 强制向系统发送设备方向变更的通知，以此强制干预全屏的最终展现方向
    if (orientationPref == 1) {
        // 1 = 强制横屏
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
    } else if (orientationPref == 2) {
        // 2 = 强制竖屏
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationPortrait] forKey:@"orientation"];
    }
    // 0 = 跟随系统 (不做任何强制干预，由设备重力感应决定)
    
    // 调用系统原生的全屏功能，它会自动继承我们上面设定的设备方向
    self.player.controlStyle = MPMovieControlStyleFullscreen;
    [self.player setFullscreen:YES animated:YES];
}

- (void)exitFullscreen {
    // 用户退出原生全屏后，恢复我们外观组件的 UI 样式
    self.player.controlStyle = MPMovieControlStyleNone;
}

- (void)toggleControls {
    self.isControlsHidden = !self.isControlsHidden;
    [UIView animateWithDuration:0.3 animations:^{
        self.topBar.alpha = self.isControlsHidden ? 0.0 : 1.0;
        self.bottomBar.alpha = self.isControlsHidden ? 0.0 : 1.0;
    }];
}

- (void)closePlayer {
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