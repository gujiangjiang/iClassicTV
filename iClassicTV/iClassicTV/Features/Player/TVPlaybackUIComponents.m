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

// 新增：保存原始文本以便在横竖屏切换时重新排版
@property (nonatomic, copy) NSString *rawCurrentProgram;
@property (nonatomic, copy) NSString *rawNextProgram;
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
    
    // 仅作为横屏下的背景色块
    self.epgOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
    self.epgOverlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    self.epgOverlayView.layer.cornerRadius = 6;
    self.epgOverlayView.clipsToBounds = YES;
    self.epgOverlayView.hidden = YES;
    [self addSubview:self.epgOverlayView];
    
    // 优化：不再作为 epgOverlayView 的子视图，以便竖屏时移动到黑边区域
    self.currentProgramLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.currentProgramLabel.textColor = isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
    self.currentProgramLabel.font = [UIFont systemFontOfSize:15];
    self.currentProgramLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.currentProgramLabel];
    
    self.nextProgramLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.nextProgramLabel.textColor = [UIColor whiteColor];
    self.nextProgramLabel.font = [UIFont systemFontOfSize:15];
    self.nextProgramLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.nextProgramLabel];
    
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
    self.catchupBadge.text = LocalizedString(@"catchup_badge");
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
    
    BOOL isPortrait = (size.height > size.width);
    
    if (isFullscreen) {
        if (isPortrait) {
            // 竖向全屏模式
            CGFloat videoHeight = size.width * 9.0 / 16.0;
            CGFloat videoY = (size.height - videoHeight) / 2.0;
            
            // 隐藏横屏下的半透明背景框
            self.epgOverlayView.hidden = YES;
            
            // 调整文本为居中多行
            self.currentProgramLabel.numberOfLines = 2;
            self.currentProgramLabel.textAlignment = NSTextAlignmentCenter;
            self.nextProgramLabel.numberOfLines = 2;
            self.nextProgramLabel.textAlignment = NSTextAlignmentCenter;
            
            CGFloat labelHeight = 50.0;
            // 将第一个节目单居中放置于上方黑色盲区
            self.currentProgramLabel.frame = CGRectMake(10, (videoY - labelHeight) / 2.0, size.width - 20, labelHeight);
            // 将第二个节目单居中放置于下方黑色盲区
            self.nextProgramLabel.frame = CGRectMake(10, videoY + videoHeight + (videoY - labelHeight) / 2.0, size.width - 20, labelHeight);
            
            self.currentProgramLabel.hidden = (self.rawCurrentProgram.length == 0);
            self.nextProgramLabel.hidden = (self.rawNextProgram.length == 0);
            
            // 时间悬浮在视频画面的右上角（而不是屏幕右上角）
            self.timeLabel.frame = CGRectMake(size.width - 80, videoY + 10, 60, 24);
            self.timeLabel.hidden = ![PlayerConfigManager showTimeInFullscreen];
            if (!self.timeLabel.hidden) [self updateSystemTime];
            
            // 回放角标悬浮在视频画面的左下角
            self.catchupBadge.frame = CGRectMake(20, videoY + videoHeight - 30, 40, 20);
            self.catchupBadge.hidden = !(self.isCatchupMode && [PlayerConfigManager showCatchupBadgeInFullscreen]);
            
        } else {
            // 横向全屏模式
            CGFloat overlayWidth = MIN(340, size.width - 140);
            CGRect epgBgFrame = CGRectMake((size.width - overlayWidth) / 2, size.height - 50 - 65, overlayWidth, 50);
            self.epgOverlayView.frame = epgBgFrame;
            
            self.currentProgramLabel.numberOfLines = 1;
            self.currentProgramLabel.textAlignment = NSTextAlignmentLeft;
            self.currentProgramLabel.frame = CGRectMake(epgBgFrame.origin.x + 10, epgBgFrame.origin.y + 5, overlayWidth - 20, 20);
            
            self.nextProgramLabel.numberOfLines = 1;
            self.nextProgramLabel.textAlignment = NSTextAlignmentLeft;
            self.nextProgramLabel.frame = CGRectMake(epgBgFrame.origin.x + 10, epgBgFrame.origin.y + 25, overlayWidth - 20, 20);
            
            BOOL hasProgram = (self.rawCurrentProgram.length > 0);
            self.epgOverlayView.hidden = !hasProgram;
            self.currentProgramLabel.hidden = !hasProgram;
            self.nextProgramLabel.hidden = !hasProgram;
            
            self.timeLabel.frame = CGRectMake(size.width - 80, 60, 60, 24);
            self.timeLabel.hidden = ![PlayerConfigManager showTimeInFullscreen];
            if (!self.timeLabel.hidden) [self updateSystemTime];
            
            self.catchupBadge.frame = CGRectMake(20, size.height - 85, 40, 20);
            self.catchupBadge.hidden = !(self.isCatchupMode && [PlayerConfigManager showCatchupBadgeInFullscreen]);
        }
        
        [self updateLabelsTextForCurrentLayout];
        
    } else {
        // 非全屏模式下隐藏所有覆盖件
        self.epgOverlayView.hidden = YES;
        self.currentProgramLabel.hidden = YES;
        self.nextProgramLabel.hidden = YES;
        self.timeLabel.hidden = YES;
        self.catchupBadge.hidden = YES;
    }
}

- (void)updateCurrentProgram:(NSString *)current nextProgram:(NSString *)next {
    self.rawCurrentProgram = current;
    self.rawNextProgram = next;
    
    [self updateLabelsTextForCurrentLayout];
    
    BOOL hasProgram = (current.length > 0);
    BOOL isPortrait = (self.bounds.size.height > self.bounds.size.width);
    
    if (isPortrait) {
        self.epgOverlayView.hidden = YES;
        self.currentProgramLabel.hidden = !hasProgram;
        self.nextProgramLabel.hidden = (next.length == 0);
    } else {
        self.epgOverlayView.hidden = !hasProgram;
        self.currentProgramLabel.hidden = !hasProgram;
        self.nextProgramLabel.hidden = !hasProgram;
    }
}

// 核心优化：竖屏下智能截断文字换行
- (void)updateLabelsTextForCurrentLayout {
    BOOL isPortrait = (self.bounds.size.height > self.bounds.size.width);
    if (isPortrait) {
        self.currentProgramLabel.text = [self insertNewlineForPortrait:self.rawCurrentProgram];
        self.nextProgramLabel.text = [self insertNewlineForPortrait:self.rawNextProgram];
    } else {
        self.currentProgramLabel.text = self.rawCurrentProgram;
        self.nextProgramLabel.text = self.rawNextProgram;
    }
}

// 通过查找冒号分隔符，将一行字符串智能切割为两行
- (NSString *)insertNewlineForPortrait:(NSString *)text {
    if (text.length == 0) return text;
    
    NSRange range = [text rangeOfString:@"："];
    if (range.location != NSNotFound) {
        return [text stringByReplacingCharactersInRange:range withString:@"：\n"];
    }
    
    if (text.length > 5) {
        // 避开时间（HH:mm）中的冒号，从第5个字符后开始寻找英文冒号
        NSRange colonRange = [text rangeOfString:@":" options:0 range:NSMakeRange(5, text.length - 5)];
        if (colonRange.location != NSNotFound) {
            if (colonRange.location + 1 < text.length && [text characterAtIndex:colonRange.location + 1] == ' ') {
                return [text stringByReplacingCharactersInRange:NSMakeRange(colonRange.location, 2) withString:@":\n"];
            }
            return [text stringByReplacingCharactersInRange:colonRange withString:@":\n"];
        }
    }
    return text;
}

- (void)updateSystemTime {
    self.timeLabel.text = [self.timeFormatter stringFromDate:[NSDate date]];
}

- (void)showStatusMessage:(NSString *)message { self.statusLabel.text = message; self.statusLabel.hidden = NO; }
- (void)hideStatusMessage { self.statusLabel.hidden = YES; }

- (void)setOverlaysHidden:(BOOL)hidden {
    self.epgOverlayView.alpha = hidden ? 0.0 : 1.0;
    self.currentProgramLabel.alpha = hidden ? 0.0 : 1.0;
    self.nextProgramLabel.alpha = hidden ? 0.0 : 1.0;
    self.timeLabel.alpha = hidden ? 0.0 : 1.0;
}

@end