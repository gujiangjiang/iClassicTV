//
//  PlayerControlView.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerControlView.h"
#import "UIImage+DynamicIcon.h"

@interface PlayerControlView ()

@property (nonatomic, strong) UIView *gestureCatcherView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UISlider *progressBar;
@property (nonatomic, strong) UIButton *fullBtn;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *lockBtn;

@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, assign) BOOL isControlsHidden;
@property (nonatomic, assign) BOOL currentIsFullscreen;
@property (nonatomic, strong) NSTimer *autoHideTimer;

@end

@implementation PlayerControlView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isLocked = NO;
        self.isControlsHidden = NO;
        self.currentIsFullscreen = NO;
        [self setupUI];
        [self startAutoHideTimer];
    }
    return self;
}

- (void)applyBlurEffectToView:(UIView *)view {
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    if (isIOS7) {
        view.backgroundColor = [UIColor clearColor];
        UIToolbar *blurBar = [[UIToolbar alloc] initWithFrame:view.bounds];
        blurBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurBar.barStyle = UIBarStyleBlack;
        blurBar.translucent = YES;
        [view insertSubview:blurBar atIndex:0];
    } else {
        view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    }
}

- (void)setupUI {
    // 1. 状态反馈层
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 100)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.statusLabel];
    
    // 2. 手势拦截层
    self.gestureCatcherView = [[UIView alloc] initWithFrame:self.bounds];
    self.gestureCatcherView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.gestureCatcherView];
    
    // 3. 底部控制栏
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 50, self.bounds.size.width, 50)];
    [self applyBlurEffectToView:self.bottomBar];
    [self addSubview:self.bottomBar];
    
    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake(5, 5, 50, 40);
    [self.playBtn setTitle:@"暂停" forState:UIControlStateNormal];
    [self.playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.playBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.playBtn addTarget:self action:@selector(playBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.playBtn];
    
    self.progressBar = [[UISlider alloc] initWithFrame:CGRectMake(60, 10, self.bounds.size.width - 155, 30)];
    self.progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.progressBar addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressBar addTarget:self action:@selector(cancelAutoHideTimer) forControlEvents:UIControlEventTouchDown];
    [self.progressBar addTarget:self action:@selector(startAutoHideTimer) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.bottomBar addSubview:self.progressBar];
    
    self.fullBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullBtn.frame = CGRectMake(self.bounds.size.width - 85, 5, 80, 40);
    [self.fullBtn setTitle:@"全屏" forState:UIControlStateNormal];
    [self.fullBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fullBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    self.fullBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.fullBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.fullBtn addTarget:self action:@selector(fullscreenBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.fullBtn];
    
    // 4. 左侧锁定按钮
    self.lockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.lockBtn.frame = CGRectMake(20, 0, 40, 40);
    self.lockBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.lockBtn.layer.cornerRadius = 20;
    self.lockBtn.alpha = 0.6;
    [self.lockBtn setImage:[UIImage dynamicLockIconWithState:NO] forState:UIControlStateNormal];
    [self.lockBtn addTarget:self action:@selector(toggleLock) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.lockBtn];
    
    // 5. 手势
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.gestureCatcherView addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.gestureCatcherView addGestureRecognizer:singleTap];
}

- (void)updateLayoutForFullscreen:(BOOL)isFullscreen videoFrame:(CGRect)videoFrame {
    self.currentIsFullscreen = isFullscreen;
    
    if (!isFullscreen && self.isLocked) {
        self.isLocked = NO;
        [self.lockBtn setImage:[UIImage dynamicLockIconWithState:NO] forState:UIControlStateNormal];
    }
    
    self.bottomBar.frame = CGRectMake(0, CGRectGetMaxY(videoFrame) - 50, self.bounds.size.width, 50);
    self.gestureCatcherView.frame = videoFrame;
    
    self.lockBtn.hidden = !isFullscreen;
    self.lockBtn.center = CGPointMake(40, CGRectGetMidY(videoFrame));
    self.statusLabel.center = CGPointMake(CGRectGetMidX(videoFrame), CGRectGetMidY(videoFrame));
    
    [self setControlsHidden:self.isControlsHidden];
}

- (void)updateProgressWithValue:(float)value { self.progressBar.value = value; }
- (void)updatePlayButtonState:(BOOL)isPlaying { [self.playBtn setTitle:(isPlaying ? @"暂停" : @"播放") forState:UIControlStateNormal]; }
- (void)updateFullscreenButtonState:(BOOL)isFullscreen { [self.fullBtn setTitle:(isFullscreen ? @"退出全屏" : @"全屏") forState:UIControlStateNormal]; }
- (void)showStatusMessage:(NSString *)message { self.statusLabel.text = message; self.statusLabel.hidden = NO; }
- (void)hideStatusMessage { self.statusLabel.hidden = YES; }

- (void)playBtnTapped {
    [self startAutoHideTimer];
    if ([self.delegate respondsToSelector:@selector(controlViewDidTapPlayPause:)]) {
        [self.delegate controlViewDidTapPlayPause:self];
    }
}

- (void)fullscreenBtnTapped {
    [self startAutoHideTimer];
    if ([self.delegate respondsToSelector:@selector(controlViewDidTapFullscreen:)]) {
        [self.delegate controlViewDidTapFullscreen:self];
    }
}

- (void)sliderValueChanged:(UISlider *)slider {
    if (self.isLocked) return;
    [self startAutoHideTimer];
    if ([self.delegate respondsToSelector:@selector(controlView:sliderValueDidChange:)]) {
        [self.delegate controlView:self sliderValueDidChange:slider.value];
    }
}

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
    [self fullscreenBtnTapped];
}

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
    if (self.isControlsHidden == hidden && !self.isLocked) return;
    self.isControlsHidden = hidden;
    
    [UIView animateWithDuration:0.3 animations:^{
        if (self.isLocked) {
            self.bottomBar.alpha = 0.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
        } else {
            self.bottomBar.alpha = hidden ? 0.0 : 1.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
        }
    }];
    
    self.bottomBar.userInteractionEnabled = !self.isLocked && !hidden;
    
    if ([self.delegate respondsToSelector:@selector(controlView:controlsHiddenDidChange:)]) {
        [self.delegate controlView:self controlsHiddenDidChange:hidden];
    }
    
    if (!hidden) [self startAutoHideTimer];
    else [self cancelAutoHideTimer];
}

- (void)dealloc {
    [self cancelAutoHideTimer];
}

@end