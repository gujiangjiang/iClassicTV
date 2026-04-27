//
//  TVPlaybackOverlayView.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackOverlayView.h"
#import "UIImage+DynamicIcon.h"

@interface TVPlaybackOverlayView () <TVPlaybackBottomBarDelegate>

@property (nonatomic, strong) TVPlaybackBottomBar *bottomBar;
@property (nonatomic, strong) TVPlaybackWidgetsView *widgetsView;

@property (nonatomic, strong) UIView *gestureCatcherView;
@property (nonatomic, strong) UIButton *lockBtn;

@property (nonatomic, strong) UIButton *centerPlayBtn;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL isManualPaused; // [核心修复] 仅代表用户真正动手点了暂停

@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, assign) BOOL isControlsHidden;
@property (nonatomic, assign) BOOL isFullscreen; // 用于内部同步记录全屏状态，以统一组件常显判断
@property (nonatomic, strong) NSTimer *autoHideTimer;

@end

@implementation TVPlaybackOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isLocked = NO;
        self.isControlsHidden = NO;
        self.isPlaying = YES; // 默认初始化即播放
        self.isManualPaused = NO;
        [self setupUI];
        [self startAutoHideTimer];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) return nil;
    return hitView;
}

- (void)setupUI {
    self.gestureCatcherView = [[UIView alloc] initWithFrame:self.bounds];
    self.gestureCatcherView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.gestureCatcherView];
    
    self.widgetsView = [[TVPlaybackWidgetsView alloc] initWithFrame:self.bounds];
    [self addSubview:self.widgetsView];
    
    // 在手势视图之上、底栏之下插入中央大按钮，确保既能点击，又不会被底栏盖住
    self.centerPlayBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.centerPlayBtn.frame = CGRectMake(0, 0, 80, 80);
    [self.centerPlayBtn setImage:[UIImage dynamicLargeCenterPlayIcon] forState:UIControlStateNormal];
    self.centerPlayBtn.alpha = 0.0;
    self.centerPlayBtn.hidden = YES;
    // 增加轻微阴影，使按钮在任何背景下都能清晰浮现
    self.centerPlayBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    self.centerPlayBtn.layer.shadowOffset = CGSizeMake(0, 2);
    self.centerPlayBtn.layer.shadowOpacity = 0.5;
    self.centerPlayBtn.layer.shadowRadius = 4.0;
    [self.centerPlayBtn addTarget:self action:@selector(centerPlayBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.centerPlayBtn];
    
    self.bottomBar = [[TVPlaybackBottomBar alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 50, self.bounds.size.width, 50)];
    self.bottomBar.delegate = self;
    [self addSubview:self.bottomBar];
    
    self.lockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.lockBtn.frame = CGRectMake(20, 0, 40, 40);
    self.lockBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.lockBtn.layer.cornerRadius = 20;
    self.lockBtn.alpha = 0.6;
    [self.lockBtn setImage:[UIImage dynamicLockIconWithState:NO] forState:UIControlStateNormal];
    [self.lockBtn addTarget:self action:@selector(toggleLock) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.lockBtn];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.gestureCatcherView addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.gestureCatcherView addGestureRecognizer:singleTap];
}

- (void)updateLayoutForFullscreen:(BOOL)isFullscreen videoFrame:(CGRect)videoFrame {
    if (!isFullscreen && self.isLocked) {
        self.isLocked = NO;
        [self.lockBtn setImage:[UIImage dynamicLockIconWithState:NO] forState:UIControlStateNormal];
    }
    
    self.isFullscreen = isFullscreen; // 记录全屏状态
    
    self.gestureCatcherView.frame = videoFrame;
    self.widgetsView.frame = videoFrame;
    self.bottomBar.frame = CGRectMake(0, CGRectGetMaxY(videoFrame) - 50, self.bounds.size.width, 50);
    
    self.lockBtn.hidden = !isFullscreen;
    self.lockBtn.center = CGPointMake(40, CGRectGetMidY(videoFrame));
    
    // 同步将大按钮居中于视频画面
    self.centerPlayBtn.center = CGPointMake(CGRectGetMidX(videoFrame), CGRectGetMidY(videoFrame));
    
    [self.widgetsView updateLayoutForFullscreen:isFullscreen parentSize:videoFrame.size];
    [self setControlsHidden:self.isControlsHidden];
}

// 仅负责底栏的状态同步
- (void)updatePlaybackState:(BOOL)isPlaying {
    self.isPlaying = isPlaying;
    [self.bottomBar updatePlayButtonState:isPlaying];
}

// [核心修复] 彻底分离手动暂停逻辑，外部明确下发指令时才改变按钮的显示状态
- (void)setManualPausedState:(BOOL)isManualPaused {
    self.isManualPaused = isManualPaused;
    
    BOOL shouldShowCenterBtn = self.isManualPaused && !self.isLocked;
    
    if (shouldShowCenterBtn) {
        self.centerPlayBtn.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.centerPlayBtn.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.25 animations:^{
            self.centerPlayBtn.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.centerPlayBtn.hidden = YES;
        }];
    }
}

// 中央大按钮点击回调，复用原有暂停播放逻辑
- (void)centerPlayBtnTapped {
    [self startAutoHideTimer];
    if ([self.delegate respondsToSelector:@selector(overlayDidTapPlayPause)]) {
        [self.delegate overlayDidTapPlayPause];
    }
}

#pragma mark - Gestures & Locks

- (void)toggleLock {
    self.isLocked = !self.isLocked;
    [self.lockBtn setImage:[UIImage dynamicLockIconWithState:self.isLocked] forState:UIControlStateNormal];
    [self setControlsHidden:NO];
    [self startAutoHideTimer];
}

- (void)handleSingleTap:(UITapGestureRecognizer *)sender {
    [self setControlsHidden:!self.isControlsHidden];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)sender {
    if (self.isLocked) return;
    if ([self.delegate respondsToSelector:@selector(overlayDidTapFullscreen)]) {
        [self.delegate overlayDidTapFullscreen];
    }
}

#pragma mark - Timer

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
    if (!self.isControlsHidden) [self setControlsHidden:YES];
}

- (void)setControlsHidden:(BOOL)hidden {
    if (self.isControlsHidden == hidden && !self.isLocked) return;
    self.isControlsHidden = hidden;
    
    [UIView animateWithDuration:0.3 animations:^{
        if (self.isLocked) {
            self.bottomBar.alpha = 0.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
            [self.widgetsView setOverlaysHidden:YES];
            self.centerPlayBtn.alpha = 0.0; // 锁屏时隐藏
        } else {
            self.bottomBar.alpha = hidden ? 0.0 : 1.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
            [self.widgetsView setOverlaysHidden:(self.isFullscreen ? hidden : NO)];
            // [核心修复] 显隐判定只跟用户手动暂停有关
            self.centerPlayBtn.alpha = self.isManualPaused ? 1.0 : 0.0;
        }
    } completion:^(BOOL finished) {
        // [核心修复] 动画结束后隐藏依据仅针对手动状态，确保手势不被阻挡
        if (self.isLocked || !self.isManualPaused) {
            self.centerPlayBtn.hidden = YES;
        } else {
            self.centerPlayBtn.hidden = NO;
        }
    }];
    
    self.bottomBar.userInteractionEnabled = !self.isLocked && !hidden;
    
    if ([self.delegate respondsToSelector:@selector(overlayControlsHiddenDidChange:)]) {
        [self.delegate overlayControlsHiddenDidChange:hidden];
    }
    
    if (!hidden) [self startAutoHideTimer];
    else [self cancelAutoHideTimer];
}

#pragma mark - TVPlaybackBottomBarDelegate

- (void)bottomBarDidTapPlayPause {
    [self startAutoHideTimer];
    if ([self.delegate respondsToSelector:@selector(overlayDidTapPlayPause)]) [self.delegate overlayDidTapPlayPause];
}

- (void)bottomBarDidTapFullscreen {
    [self startAutoHideTimer];
    if ([self.delegate respondsToSelector:@selector(overlayDidTapFullscreen)]) [self.delegate overlayDidTapFullscreen];
}

- (void)bottomBarSliderValueChanged:(float)value {
    [self startAutoHideTimer];
    if ([self.delegate respondsToSelector:@selector(overlaySliderValueChanged:)]) [self.delegate overlaySliderValueChanged:value];
}

- (void)bottomBarSliderDidTouchDown {
    [self cancelAutoHideTimer];
}

- (void)bottomBarSliderDidRelease {
    [self startAutoHideTimer];
}

#pragma mark - Proxies

- (void)showStatusMessage:(NSString *)message { [self.widgetsView showStatusMessage:message]; }
- (void)hideStatusMessage { [self.widgetsView hideStatusMessage]; }

- (void)dealloc {
    [self cancelAutoHideTimer];
}

@end