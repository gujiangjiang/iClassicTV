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
@property (nonatomic, assign) BOOL currentIsFullscreen; // 新增：记录当前是否全屏
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

// 新增：根据系统版本应用对应的背景风格 (iOS7毛玻璃 / iOS6拟物黑)
- (void)applyBlurEffectToView:(UIView *)view {
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    if (isIOS7) {
        view.backgroundColor = [UIColor clearColor];
        UIToolbar *blurBar = [[UIToolbar alloc] initWithFrame:view.bounds];
        blurBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurBar.barStyle = UIBarStyleBlack;
        blurBar.translucent = YES;
        [view insertSubview:blurBar atIndex:0]; // 垫在最底层实现毛玻璃
    } else {
        view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    }
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
    [self addSubview:self.gestureCatcherView];
    
    // 3. 顶部导航栏
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 44)];
    self.topBar.backgroundColor = [UIColor clearColor];
    [self addSubview:self.topBar];
    
    // 修复：废弃普通的视图毛玻璃背景，直接嵌入系统原生的 UINavigationBar 作为顶栏背景
    // 这完美解决了“缺少顶栏”的视觉问题，在竖屏模式下彻底还原 iOS6/7 最真实的顶栏原生质感
    UINavigationBar *topNavBg = [[UINavigationBar alloc] initWithFrame:self.topBar.bounds];
    topNavBg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    topNavBg.barStyle = UIBarStyleBlack; // 保持深色主题与白色文字的契合
    topNavBg.tag = 999; // 打个标记，方便布局刷新时单独处理它
    [self.topBar addSubview:topNavBg];
    
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
    [self applyBlurEffectToView:self.bottomBar]; // 底部悬浮区域仍然保持透明沉浸感
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

// 新增：动态重算控制组件的 Frame 以适应半屏/全屏
- (void)updateLayoutForFullscreen:(BOOL)isFullscreen videoFrame:(CGRect)videoFrame {
    self.currentIsFullscreen = isFullscreen;
    
    // 竖屏半屏时解开可能遗留的锁定状态
    if (!isFullscreen && self.isLocked) {
        self.isLocked = NO;
        [self.lockBtn setImage:[UIImage dynamicLockIconWithState:NO] forState:UIControlStateNormal];
    }
    
    // 全屏时隐藏了状态栏，非全屏时显示状态栏。动态补偿高度避免内容被遮挡
    CGFloat topBarHeight = isFullscreen ? 44.0 : 64.0;
    CGFloat yOffset = isFullscreen ? 0.0 : 20.0;
    
    self.topBar.frame = CGRectMake(0, 0, self.bounds.size.width, topBarHeight);
    
    // 调整 topBar 内部元素的垂直偏移，并精细适配原生导航栏的尺寸
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    for (UIView *subview in self.topBar.subviews) {
        if (subview.tag == 999) { // 针对新添加的 UINavigationBar 背景做兼容适配
            if (!isIOS7 && !isFullscreen) {
                // 修复：iOS 6 竖屏时系统导航栏不支持延伸至状态栏下方，高度必须强制设为 44，并向下偏移 20
                subview.frame = CGRectMake(0, 20, self.bounds.size.width, 44);
            } else {
                // iOS 7+ 或者是横屏（无状态栏/透明状态栏），直接填满 topBar 完美适配
                subview.frame = self.topBar.bounds;
            }
        } else if ([subview isKindOfClass:[UIButton class]]) {
            subview.frame = CGRectMake(5, yOffset, 60, 44);
        } else if ([subview isKindOfClass:[UILabel class]]) {
            subview.frame = CGRectMake(70, yOffset, self.bounds.size.width - 140, 44);
        }
    }
    
    // BottomBar 紧贴视频区域底部悬浮
    self.bottomBar.frame = CGRectMake(0, CGRectGetMaxY(videoFrame) - 50, self.bounds.size.width, 50);
    
    // 触控感应区域与视频区域重叠
    self.gestureCatcherView.frame = videoFrame;
    
    // 锁定按钮仅在全屏可用并居左对齐
    self.lockBtn.hidden = !isFullscreen;
    self.lockBtn.center = CGPointMake(40, CGRectGetMidY(videoFrame));
    
    // 状态文字在视频居中
    self.statusLabel.center = CGPointMake(CGRectGetMidX(videoFrame), CGRectGetMidY(videoFrame));
    
    // 触发一次隐藏状态校验，确保非全屏时顶部常显
    [self setControlsHidden:self.isControlsHidden];
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
            // 优化：竖屏非全屏模式下，顶部栏作为系统导航栏功能，决不能被隐藏
            self.topBar.alpha = (!self.currentIsFullscreen) ? 1.0 : (hidden ? 0.0 : 1.0);
            self.bottomBar.alpha = hidden ? 0.0 : 1.0;
            self.lockBtn.alpha = hidden ? 0.0 : 0.6;
        }
    }];
    
    self.topBar.userInteractionEnabled = !self.isLocked;
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