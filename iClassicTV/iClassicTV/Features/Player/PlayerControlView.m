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
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UISlider *progressBar;
@property (nonatomic, strong) UIButton *fullBtn;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *lockBtn;

@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, assign) BOOL isControlsHidden;
@property (nonatomic, strong) NSTimer *autoHideTimer;

@end

@implementation PlayerControlView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isLocked = NO;
        self.isControlsHidden = NO;
        [self setupUI];
        [self startAutoHideTimer];
    }
    return self;
}

- (void)setupUI {
    // 1. 状态反馈提示层
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 100)];
    self.statusLabel.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.text = @"加载中...";
    [self addSubview:self.statusLabel];
    
    // 2. 手势拦截层
    self.gestureCatcherView = [[UIView alloc] initWithFrame:self.bounds];
    self.gestureCatcherView.backgroundColor = [UIColor clearColor];
    self.gestureCatcherView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.gestureCatcherView];
    
    // 3. 顶部导航栏
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 44)];
    self.topBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    self.topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:self.topBar];
    
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(5, 0, 60, 44);
    [backBtn setTitle:@"< 返回" forState:UIControlStateNormal];
    [backBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [backBtn addTarget:self action:@selector(backBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:backBtn];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, self.bounds.size.width - 140, 44)];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topBar addSubview:self.titleLabel];
    
    // 4. 底部控制栏
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 50, self.bounds.size.width, 50)];
    self.bottomBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
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
    
    // 5. 左侧锁定按钮
    self.lockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.lockBtn.frame = CGRectMake(20, (self.bounds.size.height - 40) / 2, 40, 40);
    self.lockBtn.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    self.lockBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.lockBtn.layer.cornerRadius = 20;
    self.lockBtn.alpha = 0.6;
    [self.lockBtn setImage:[UIImage dynamicLockIconWithState:NO] forState:UIControlStateNormal];
    [self.lockBtn addTarget:self action:@selector(toggleLock) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.lockBtn];
    
    // 6. 添加手势控制
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.gestureCatcherView addGestureRecognizer:doubleTap];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.gestureCatcherView addGestureRecognizer:singleTap];
}

#pragma mark - 公开更新接口

- (void)setChannelTitle:(NSString *)title {
    self.titleLabel.text = title;
}

- (void)updateProgressWithValue:(float)value {
    self.progressBar.value = value;
}

- (void)updatePlayButtonState:(BOOL)isPlaying {
    [self.playBtn setTitle:(isPlaying ? @"暂停" : @"播放") forState:UIControlStateNormal];
}

- (void)updateFullscreenButtonState:(BOOL)isFullscreen {
    [self.fullBtn setTitle:(isFullscreen ? @"退出全屏" : @"全屏") forState:UIControlStateNormal];
}

- (void)showStatusMessage:(NSString *)message {
    self.statusLabel.text = message;
    self.statusLabel.hidden = NO;
}

- (void)hideStatusMessage {
    self.statusLabel.hidden = YES;
}

#pragma mark - UI 交互事件转发

- (void)backBtnTapped {
    if ([self.delegate respondsToSelector:@selector(controlViewDidTapBack:)]) {
        [self.delegate controlViewDidTapBack:self];
    }
}

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

#pragma mark - 自动隐藏逻辑

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
            self.topBar.alpha = 0.0;
            self.bottomBar.alpha = 0.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
        } else {
            self.topBar.alpha = hidden ? 0.0 : 1.0;
            self.bottomBar.alpha = hidden ? 0.0 : 1.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
        }
    }];
    
    self.topBar.userInteractionEnabled = !self.isLocked && !hidden;
    self.bottomBar.userInteractionEnabled = !self.isLocked && !hidden;
    
    // 通知控制器 UI 隐藏状态改变，以便控制器更新状态栏
    if ([self.delegate respondsToSelector:@selector(controlView:controlsHiddenDidChange:)]) {
        [self.delegate controlView:self controlsHiddenDidChange:hidden];
    }
    
    if (!hidden) {
        [self startAutoHideTimer];
    } else {
        [self cancelAutoHideTimer];
    }
}

- (void)dealloc {
    [self cancelAutoHideTimer];
}

@end