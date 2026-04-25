//
//  TVPlaybackUIComponents.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackUIComponents.h"
#import "LanguageManager.h"
#import "PlayerConfigManager.h"

#pragma mark - ====== TVPlaybackBottomBar 实现 ======

@interface TVPlaybackBottomBar ()
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UISlider *progressBar;
@property (nonatomic, strong) UIButton *fullBtn;
@end

@implementation TVPlaybackBottomBar

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self applyBlurEffect];
        [self setupUI];
    }
    return self;
}

- (void)applyBlurEffect {
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    if (isIOS7) {
        self.backgroundColor = [UIColor clearColor];
        UIToolbar *blurBar = [[UIToolbar alloc] initWithFrame:self.bounds];
        blurBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurBar.barStyle = UIBarStyleBlack;
        blurBar.translucent = YES;
        [self insertSubview:blurBar atIndex:0];
    } else {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    }
}

- (void)setupUI {
    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake(5, 5, 50, 40);
    [self.playBtn setTitle:LocalizedString(@"pause") forState:UIControlStateNormal];
    [self.playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.playBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.playBtn addTarget:self action:@selector(playBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.playBtn];
    
    self.progressBar = [[UISlider alloc] initWithFrame:CGRectMake(60, 10, self.bounds.size.width - 155, 30)];
    self.progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.progressBar addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressBar addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.progressBar addTarget:self action:@selector(sliderTouchRelease) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addSubview:self.progressBar];
    
    self.fullBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullBtn.frame = CGRectMake(self.bounds.size.width - 85, 5, 80, 40);
    [self.fullBtn setTitle:LocalizedString(@"fullscreen") forState:UIControlStateNormal];
    [self.fullBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fullBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    self.fullBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.fullBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.fullBtn addTarget:self action:@selector(fullscreenBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.fullBtn];
}

- (void)updateProgressWithValue:(float)value { self.progressBar.value = value; }
- (void)updatePlayButtonState:(BOOL)isPlaying { [self.playBtn setTitle:(isPlaying ? LocalizedString(@"pause") : LocalizedString(@"play")) forState:UIControlStateNormal]; }
- (void)updateFullscreenButtonState:(BOOL)isFullscreen { [self.fullBtn setTitle:(isFullscreen ? LocalizedString(@"exit_fullscreen") : LocalizedString(@"fullscreen")) forState:UIControlStateNormal]; }

- (void)playBtnTapped { if ([self.delegate respondsToSelector:@selector(bottomBarDidTapPlayPause)]) [self.delegate bottomBarDidTapPlayPause]; }
- (void)fullscreenBtnTapped { if ([self.delegate respondsToSelector:@selector(bottomBarDidTapFullscreen)]) [self.delegate bottomBarDidTapFullscreen]; }
- (void)sliderValueChanged:(UISlider *)slider { if ([self.delegate respondsToSelector:@selector(bottomBarSliderValueChanged:)]) [self.delegate bottomBarSliderValueChanged:slider.value]; }
- (void)sliderTouchDown { if ([self.delegate respondsToSelector:@selector(bottomBarSliderDidTouchDown)]) [self.delegate bottomBarSliderDidTouchDown]; }
- (void)sliderTouchRelease { if ([self.delegate respondsToSelector:@selector(bottomBarSliderDidRelease)]) [self.delegate bottomBarSliderDidRelease]; }

@end


#pragma mark - ====== TVPlaybackWidgetsView 实现 ======

@interface TVPlaybackWidgetsView ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *epgOverlayView;
@property (nonatomic, strong) UILabel *currentProgramLabel;
@property (nonatomic, strong) UILabel *nextProgramLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) UILabel *catchupBadge;
@end

@implementation TVPlaybackWidgetsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isCatchupMode = NO;
        [self setupUI];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) return nil;
    return hitView;
}

- (void)setupUI {
    BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 100)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.hidden = YES;
    [self addSubview:self.statusLabel];
    
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
}

- (void)updateLayoutForFullscreen:(BOOL)isFullscreen parentSize:(CGSize)size {
    self.statusLabel.center = CGPointMake(size.width / 2.0, size.height / 2.0);
    
    if (isFullscreen) {
        CGFloat overlayWidth = MIN(400, size.width - 60);
        self.epgOverlayView.frame = CGRectMake((size.width - overlayWidth) / 2, size.height - 50 - 65, overlayWidth, 50);
        self.currentProgramLabel.frame = CGRectMake(10, 5, overlayWidth - 20, 20);
        self.nextProgramLabel.frame = CGRectMake(10, 25, overlayWidth - 20, 20);
        self.epgOverlayView.hidden = (self.currentProgramLabel.text.length == 0);
        
        self.timeLabel.frame = CGRectMake(size.width - 80, 60, 60, 24);
        self.timeLabel.hidden = ![PlayerConfigManager showTimeInFullscreen];
        if (!self.timeLabel.hidden) [self updateSystemTime];
        
        self.catchupBadge.frame = CGRectMake(20, size.height - 85, 40, 20);
        self.catchupBadge.hidden = !(self.isCatchupMode && [PlayerConfigManager showCatchupBadgeInFullscreen]);
    } else {
        self.epgOverlayView.hidden = YES;
        self.timeLabel.hidden = YES;
        self.catchupBadge.hidden = YES;
    }
}

- (void)updateCurrentProgram:(NSString *)current nextProgram:(NSString *)next {
    self.currentProgramLabel.text = current;
    self.nextProgramLabel.text = next;
    self.epgOverlayView.hidden = (current.length == 0);
}

- (void)updateSystemTime {
    self.timeLabel.text = [self.timeFormatter stringFromDate:[NSDate date]];
}

- (void)showStatusMessage:(NSString *)message { self.statusLabel.text = message; self.statusLabel.hidden = NO; }
- (void)hideStatusMessage { self.statusLabel.hidden = YES; }

// 新增：单独控制需要动画隐藏的浮层，绝对不影响 statusLabel 和 catchupBadge 的状态
- (void)setOverlaysHidden:(BOOL)hidden {
    self.epgOverlayView.alpha = hidden ? 0.0 : 1.0;
    self.timeLabel.alpha = hidden ? 0.0 : 1.0;
}

@end