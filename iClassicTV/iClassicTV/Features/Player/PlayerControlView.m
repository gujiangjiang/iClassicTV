//
//  PlayerControlView.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerControlView.h"
#import "UIImage+DynamicIcon.h"
#import "LanguageManager.h"
#import "PlayerConfigManager.h"

@interface PlayerControlView ()

@property (nonatomic, strong) UIView *gestureCatcherView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UISlider *progressBar;
@property (nonatomic, strong) UIButton *fullBtn;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *lockBtn;

// 全屏 EPG 悬浮窗组件
@property (nonatomic, strong) UIView *epgOverlayView;
@property (nonatomic, strong) UILabel *currentProgramLabel;
@property (nonatomic, strong) UILabel *nextProgramLabel;

// 全屏右上角的时间悬浮组件
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;

// 防遮挡全屏常驻回放角标
@property (nonatomic, strong) UILabel *catchupBadge;

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
        self.isCatchupMode = NO;
        [self setupUI];
        [self startAutoHideTimer];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) {
        return nil;
    }
    return hitView;
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
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 100)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.statusLabel];
    
    self.gestureCatcherView = [[UIView alloc] initWithFrame:self.bounds];
    self.gestureCatcherView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.gestureCatcherView];
    
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 50, self.bounds.size.width, 50)];
    [self applyBlurEffectToView:self.bottomBar];
    [self addSubview:self.bottomBar];
    
    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake(5, 5, 50, 40);
    [self.playBtn setTitle:LocalizedString(@"pause") forState:UIControlStateNormal];
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
    [self.fullBtn setTitle:LocalizedString(@"fullscreen") forState:UIControlStateNormal];
    [self.fullBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fullBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    self.fullBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.fullBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.fullBtn addTarget:self action:@selector(fullscreenBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.fullBtn];
    
    self.lockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.lockBtn.frame = CGRectMake(20, 0, 40, 40);
    self.lockBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.lockBtn.layer.cornerRadius = 20;
    self.lockBtn.alpha = 0.6;
    [self.lockBtn setImage:[UIImage dynamicLockIconWithState:NO] forState:UIControlStateNormal];
    [self.lockBtn addTarget:self action:@selector(toggleLock) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.lockBtn];
    
    self.epgOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
    self.epgOverlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    self.epgOverlayView.layer.cornerRadius = 6;
    self.epgOverlayView.clipsToBounds = YES;
    self.epgOverlayView.hidden = YES;
    [self addSubview:self.epgOverlayView];
    
    self.currentProgramLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.currentProgramLabel.textColor = isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
    self.currentProgramLabel.font = [UIFont systemFontOfSize:15];
    self.currentProgramLabel.backgroundColor = [UIColor clearColor];
    [self.epgOverlayView addSubview:self.currentProgramLabel];
    
    self.nextProgramLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.nextProgramLabel.textColor = [UIColor whiteColor];
    self.nextProgramLabel.font = [UIFont systemFontOfSize:15];
    self.nextProgramLabel.backgroundColor = [UIColor clearColor];
    [self.epgOverlayView addSubview:self.nextProgramLabel];
    
    self.timeFormatter = [[NSDateFormatter alloc] init];
    [self.timeFormatter setDateFormat:@"HH:mm"];
    
    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.timeLabel.textColor = [UIColor whiteColor];
    self.timeLabel.font = [UIFont boldSystemFontOfSize:16];
    self.timeLabel.textAlignment = NSTextAlignmentRight;
    self.timeLabel.backgroundColor = [UIColor clearColor];
    self.timeLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.timeLabel.shadowOffset = CGSizeMake(1, 1);
    self.timeLabel.hidden = YES;
    [self addSubview:self.timeLabel];
    
    self.catchupBadge = [[UILabel alloc] initWithFrame:CGRectZero];
    self.catchupBadge.text = @"回放";
    self.catchupBadge.textColor = [UIColor whiteColor];
    self.catchupBadge.backgroundColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:0.9];
    self.catchupBadge.font = [UIFont boldSystemFontOfSize:12];
    self.catchupBadge.textAlignment = NSTextAlignmentCenter;
    self.catchupBadge.layer.cornerRadius = 3;
    self.catchupBadge.clipsToBounds = YES;
    self.catchupBadge.hidden = YES;
    [self addSubview:self.catchupBadge];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.gestureCatcherView addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.gestureCatcherView addGestureRecognizer:singleTap];
}

// [修改] 自动响应回放状态的变更以控制常驻角标的显示和隐藏，加入全局设置项判断
- (void)setIsCatchupMode:(BOOL)isCatchupMode {
    _isCatchupMode = isCatchupMode;
    if (self.currentIsFullscreen && isCatchupMode && [PlayerConfigManager showCatchupBadgeInFullscreen]) {
        self.catchupBadge.hidden = NO;
    } else {
        self.catchupBadge.hidden = YES;
    }
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
    
    if (isFullscreen) {
        CGFloat overlayWidth = MIN(400, self.bounds.size.width - 60);
        self.epgOverlayView.frame = CGRectMake((self.bounds.size.width - overlayWidth) / 2, self.bounds.size.height - 50 - 65, overlayWidth, 50);
        self.currentProgramLabel.frame = CGRectMake(10, 5, overlayWidth - 20, 20);
        self.nextProgramLabel.frame = CGRectMake(10, 25, overlayWidth - 20, 20);
        
        self.epgOverlayView.hidden = (self.currentProgramLabel.text.length == 0);
        
        self.timeLabel.frame = CGRectMake(self.bounds.size.width - 80, 60, 60, 24);
        self.timeLabel.hidden = ![PlayerConfigManager showTimeInFullscreen];
        if (!self.timeLabel.hidden) {
            [self updateSystemTime];
        }
        
        self.catchupBadge.frame = CGRectMake(20, self.bounds.size.height - 85, 40, 20);
        // [修改] 判断当前处于全屏时，同时满足回看模式且设置开启，才展示回看角标
        self.catchupBadge.hidden = !(self.isCatchupMode && [PlayerConfigManager showCatchupBadgeInFullscreen]);
    } else {
        self.epgOverlayView.hidden = YES;
        self.timeLabel.hidden = YES;
        self.catchupBadge.hidden = YES;
    }
    
    [self setControlsHidden:self.isControlsHidden];
}

- (void)updateCurrentProgram:(NSString *)current nextProgram:(NSString *)next {
    self.currentProgramLabel.text = current;
    self.nextProgramLabel.text = next;
    
    if (self.currentIsFullscreen && current.length > 0) {
        self.epgOverlayView.hidden = NO;
    } else {
        self.epgOverlayView.hidden = YES;
    }
}

- (void)updateSystemTime {
    if (!self.currentIsFullscreen || ![PlayerConfigManager showTimeInFullscreen]) {
        return;
    }
    self.timeLabel.text = [self.timeFormatter stringFromDate:[NSDate date]];
}

- (void)updateProgressWithValue:(float)value { self.progressBar.value = value; }
- (void)updatePlayButtonState:(BOOL)isPlaying { [self.playBtn setTitle:(isPlaying ? LocalizedString(@"pause") : LocalizedString(@"play")) forState:UIControlStateNormal]; }
- (void)updateFullscreenButtonState:(BOOL)isFullscreen { [self.fullBtn setTitle:(isFullscreen ? LocalizedString(@"exit_fullscreen") : LocalizedString(@"fullscreen")) forState:UIControlStateNormal]; }
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
            self.epgOverlayView.alpha = hidden ? 0.0 : 1.0;
            self.timeLabel.alpha = hidden ? 0.0 : 1.0;
        } else {
            self.bottomBar.alpha = hidden ? 0.0 : 1.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
            self.epgOverlayView.alpha = hidden ? 0.0 : 1.0;
            self.timeLabel.alpha = hidden ? 0.0 : 1.0;
        }
        // catchupBadge 的 alpha 在动画中故意不产生变更，实现常驻屏幕显示的效果
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