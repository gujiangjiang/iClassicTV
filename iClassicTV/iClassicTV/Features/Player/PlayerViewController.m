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
#import "LanguageManager.h" // 引入多语言模块
#import "EPGManager.h"      // 引入 EPG 管理器
#import "EPGProgram.h"      // 引入 EPG 节目模型

// 新增 UITableViewDelegate 和 UITableViewDataSource 协议
@interface PlayerViewController () <PlayerControlViewDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) PlayerControlView *controlView;

@property (nonatomic, strong) UINavigationBar *navBar; // 接管原生的顶部导航栏
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UILabel *tipsLabel;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;

// 新增的 EPG 相关属性
@property (nonatomic, strong) UITableView *epgTableView;
@property (nonatomic, strong) NSArray *epgPrograms;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    // 优化：移除了 iOS 6 下容易导致 Modal 视图首次布局错位的 wantsFullScreenLayout = YES，
    // 改为让系统自动处理状态栏的 20pt 下沉，以彻底解决首次进入时多出一个状态栏高度缝隙的 Bug。
    
    self.backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.backgroundView];
    
    // 初始化时间格式化器，用于在列表中展示 HH:mm 格式的时间
    self.timeFormatter = [[NSDateFormatter alloc] init];
    [self.timeFormatter setDateFormat:@"HH:mm"];
    
    // 获取当前频道的 EPG 数据
    if ([EPGManager sharedManager].isEPGEnabled) {
        NSArray *programs = [[EPGManager sharedManager] programsForChannelName:self.channelTitle];
        self.epgPrograms = programs ? programs : @[];
    } else {
        self.epgPrograms = @[];
    }
    
    // EPG TableView 初始化，挂载在底层
    self.epgTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.epgTableView.backgroundColor = [UIColor clearColor];
    self.epgTableView.delegate = self;
    self.epgTableView.dataSource = self;
    // iOS 6 分割线颜色调整，使其在深色背景下不显得突兀
    self.epgTableView.separatorColor = [UIColor darkGrayColor];
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        self.epgTableView.separatorInset = UIEdgeInsetsZero;
    }
    [self.view addSubview:self.epgTableView];
    
    // 原先的 tipsLabel 保留，当没有 EPG 数据时用于展示空状态提示
    self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.tipsLabel.backgroundColor = [UIColor clearColor];
    self.tipsLabel.textAlignment = NSTextAlignmentCenter;
    self.tipsLabel.textColor = [UIColor grayColor];
    self.tipsLabel.font = [UIFont systemFontOfSize:14];
    self.tipsLabel.text = @"暂无节目单数据";
    self.tipsLabel.numberOfLines = 0;
    self.tipsLabel.hidden = (self.epgPrograms.count > 0);
    [self.view addSubview:self.tipsLabel];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    NSURL *url = [NSURL URLWithString:[self.videoURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.player.controlStyle = MPMovieControlStyleNone;
    [self.view addSubview:self.player.view];
    
    // 挂载控制层 (纯净版)
    self.controlView = [[PlayerControlView alloc] initWithFrame:self.view.bounds];
    self.controlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.controlView.delegate = self;
    [self.view addSubview:self.controlView];
    
    // 构建并挂载真正的系统原生 UINavigationBar 放在最顶层
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:self.channelTitle ?: LocalizedString(@"unknown_channel")];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"back") style:UIBarButtonItemStyleBordered target:self action:@selector(closePlayer)];
    navItem.leftBarButtonItem = backItem;
    [self.navBar pushNavigationItem:navItem animated:NO];
    [self.view addSubview:self.navBar];
    
    // 监听内核状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadStateChanged) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaTypesAvailable) name:MPMovieMediaTypesAvailableNotification object:self.player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    [self.player play];
    [self startTimer];
    [self updateNowPlayingInfo];
    
    // 延迟滑动到当前正在播放的节目以确保 TableView 已经完成初始布局
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollToCurrentProgram];
    });
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
        
        // 全屏时隐藏 EPG 列表和空状态提示
        self.epgTableView.hidden = YES;
        self.tipsLabel.hidden = YES;
        
        // 全屏时：原生的黑色毛玻璃导航栏
        self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
        self.navBar.barStyle = UIBarStyleBlack;
    } else {
        // 优化：修复 iOS 6 下的 topBarHeight 为 44.0，适配移除了 wantsFullScreenLayout 后的逻辑
        CGFloat topBarHeight = isIOS7 ? 64.0 : 44.0;
        CGFloat videoHeight = self.view.bounds.size.width * 9.0 / 16.0;
        videoFrame = CGRectMake(0, topBarHeight, self.view.bounds.size.width, videoHeight);
        
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.backgroundColor = isIOS7 ? [UIColor groupTableViewBackgroundColor] : [UIColor scrollViewTexturedBackgroundColor];
        
        // 竖屏时展现 EPG 列表，计算视频下方的闲置空间
        CGFloat tableY = CGRectGetMaxY(videoFrame);
        CGFloat tableHeight = self.view.bounds.size.height - tableY;
        self.epgTableView.frame = CGRectMake(0, tableY, self.view.bounds.size.width, tableHeight);
        self.epgTableView.hidden = NO;
        
        self.tipsLabel.frame = CGRectMake(20, tableY + 30, self.view.bounds.size.width - 40, 40);
        self.tipsLabel.hidden = (self.epgPrograms.count > 0);
        
        // 竖屏时：完全跟随 iOS 版本的原生状态栏与导航栏布局
        if (isIOS7) {
            self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 64);
            self.navBar.barStyle = UIBarStyleDefault; // 系统经典浅色
        } else {
            // 优化：将 iOS 6 的 Y 坐标从 20 调整为 0，因为移除了 wantsFullScreenLayout 后，系统会自动下推 self.view 避开状态栏
            self.navBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
            self.navBar.barStyle = UIBarStyleBlack;   // iOS6 经典深色高光
        }
    }
    
    // 即时更新导航栏隐藏状态，避免旋转时跳动
    if (self.controlView.isLocked) {
        self.navBar.alpha = 0.0;
    } else {
        self.navBar.alpha = (!self.isFullscreen) ? 1.0 : (self.isControlsHidden ? 0.0 : 1.0);
    }
    
    self.player.view.frame = videoFrame;
    [self.controlView updateLayoutForFullscreen:self.isFullscreen videoFrame:videoFrame];
}

#pragma mark - UITableViewDataSource & UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.epgPrograms.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EPGCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        // 使用 Value1 样式：左边节目名，右边时间
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.selectionStyle = UITableViewCellSelectionStyleNone; // 节目单只做展示，不可点击
    }
    
    EPGProgram *program = self.epgPrograms[indexPath.row];
    NSString *timeString = [self.timeFormatter stringFromDate:program.startTime];
    cell.textLabel.text = program.title;
    cell.detailTextLabel.text = timeString;
    
    NSDate *now = [NSDate date];
    // 判断逻辑：当前时间 >= 开始时间 且 当前时间 < 结束时间
    if ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending) {
        // 正在播放，使用醒目颜色高亮
        cell.textLabel.textColor = [UIColor orangeColor];
        cell.detailTextLabel.textColor = [UIColor orangeColor];
    } else if ([now compare:program.endTime] != NSOrderedAscending) {
        // 已播完的节目置灰
        cell.textLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    } else {
        // 未播放的节目，适配 iOS 6 与 iOS 7 的底色
        BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        UIColor *normalColor = isIOS7 ? [UIColor blackColor] : [UIColor whiteColor];
        cell.textLabel.textColor = normalColor;
        cell.detailTextLabel.textColor = normalColor;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

#pragma mark - EPG 辅助方法

// 自动滚动到当前正在播放的节目
- (void)scrollToCurrentProgram {
    if (self.epgPrograms.count == 0) return;
    
    NSDate *now = [NSDate date];
    NSInteger currentIndex = -1;
    
    for (NSInteger i = 0; i < self.epgPrograms.count; i++) {
        EPGProgram *p = self.epgPrograms[i];
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            currentIndex = i;
            break;
        }
    }
    
    // 如果找到了当前正在播放的节目，自动滚动并将其居中显示
    if (currentIndex >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
        [self.epgTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
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
    
    // 优化：将这里的状态栏更新逻辑移除，统一收口交由 willAnimateRotationToInterfaceOrientation 处理，
    // 确保物理旋转和按钮旋转都能完美同步状态栏。
}

- (void)controlView:(PlayerControlView *)controlView sliderValueDidChange:(float)value {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = value * self.player.duration;
    }
}

- (void)controlView:(PlayerControlView *)controlView controlsHiddenDidChange:(BOOL)isHidden {
    self.isControlsHidden = isHidden;
    
    // 联动系统原生导航栏执行淡入淡出
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
    
    // 优化：在这里统一接管所有的状态栏更新逻辑，无论是手动物理旋转还是点击按钮强制旋转，
    // 都确保能正确触发 iOS 6 和 iOS 7 的状态栏隐藏，修复了全屏发白通知栏的 Bug。
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
    self.isFullscreen = isLandscape; // 预先更新标识位以确保后续取值准确
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:isLandscape withAnimation:UIStatusBarAnimationFade];
    }
    
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

@end