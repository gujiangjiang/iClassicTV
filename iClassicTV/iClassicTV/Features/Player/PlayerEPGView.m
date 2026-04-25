//
//  PlayerEPGView.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView.h"
#import "EPGManager.h"
#import "EPGProgram.h"
#import "LanguageManager.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - 新增：自定义跑马灯 Label
@interface EPGMarqueeLabel : UIView
@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, assign) CGSize shadowOffset;
- (void)startAnimation;
@end

@interface EPGMarqueeLabel ()
// 修复：记录上一次的尺寸和边界，防止滚动列表时触发 layoutSubviews 意外打断正在播放的动画
@property (nonatomic, assign) CGSize lastTextSize;
@property (nonatomic, assign) CGRect lastBounds;
@end

@implementation EPGMarqueeLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor clearColor];
        self.textLabel = [[UILabel alloc] initWithFrame:self.bounds];
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.textLabel.lineBreakMode = NSLineBreakByClipping; // 禁用省略号，依赖容器截断
        [self addSubview:self.textLabel];
    }
    return self;
}

- (void)setText:(NSString *)text {
    if (![_text isEqualToString:text]) {
        _text = text;
        self.textLabel.text = text;
        self.lastTextSize = CGSizeZero; // 迫使重新计算布局和动画
        [self setNeedsLayout];
    }
}

- (void)setFont:(UIFont *)font {
    if (_font != font) {
        _font = font;
        self.textLabel.font = font;
        self.lastTextSize = CGSizeZero; // 迫使重新计算布局和动画
        [self setNeedsLayout];
    }
}

- (void)setTextColor:(UIColor *)textColor {
    _textColor = textColor;
    self.textLabel.textColor = textColor;
}

- (void)setShadowColor:(UIColor *)shadowColor {
    _shadowColor = shadowColor;
    self.textLabel.shadowColor = shadowColor;
}

- (void)setShadowOffset:(CGSize)shadowOffset {
    _shadowOffset = shadowOffset;
    self.textLabel.shadowOffset = shadowOffset;
}

- (void)startAnimation {
    self.lastTextSize = CGSizeZero;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 修复：如果还没加载出来视图或者没有文本，直接返回，避免运算错误
    if (self.bounds.size.width == 0 || self.text.length == 0) {
        return;
    }
    
    // 修复：弃用容易导致高度或宽度被截断为0的 sizeToFit，改为严谨地按照字号计算需要的真实宽度
    CGSize textSize;
    if ([self.text respondsToSelector:@selector(sizeWithAttributes:)]) {
        textSize = [self.text sizeWithAttributes:@{NSFontAttributeName: self.textLabel.font}];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        textSize = [self.text sizeWithFont:self.textLabel.font];
#pragma clang diagnostic pop
    }
    
    CGFloat viewWidth = self.bounds.size.width;
    CGFloat viewHeight = self.bounds.size.height;
    CGFloat finalWidth = MAX(textSize.width + 5.0, viewWidth); // 留点边距防止切掉文字边缘
    
    // 优化：如果内容和容器尺寸都没有变化，则不打断当前正在进行的动画
    if (CGSizeEqualToSize(self.lastTextSize, textSize) && CGRectEqualToRect(self.lastBounds, self.bounds)) {
        return;
    }
    
    self.lastTextSize = textSize;
    self.lastBounds = self.bounds;
    
    [self.textLabel.layer removeAllAnimations];
    self.textLabel.transform = CGAffineTransformIdentity;
    self.textLabel.frame = CGRectMake(0, 0, finalWidth, viewHeight);
    
    if (finalWidth > viewWidth) {
        CGFloat overlap = finalWidth - viewWidth;
        NSTimeInterval duration = overlap * 0.04 + 1.0; // 根据溢出长度计算动画时间，保证匀速线性滚动
        
        // 采用 UIViewAnimationOptionCurveLinear 保证跑马灯平滑
        [UIView animateWithDuration:duration delay:1.5 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction animations:^{
            self.textLabel.transform = CGAffineTransformMakeTranslation(-overlap, 0);
        } completion:nil];
    }
}
@end

#pragma mark - 新增：自定义节目 Cell，优化排版确保状态文本不被截断
@interface EPGProgramCell : UITableViewCell
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) EPGMarqueeLabel *titleMarqueeLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation EPGProgramCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        self.timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.timeLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:self.timeLabel];
        
        self.titleMarqueeLabel = [[EPGMarqueeLabel alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:self.titleMarqueeLabel];
        
        self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.statusLabel.backgroundColor = [UIColor clearColor];
        self.statusLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:self.statusLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width;
    CGFloat height = self.contentView.bounds.size.height;
    
    // 1. 时间固定宽度
    CGFloat timeWidth = 45.0;
    self.timeLabel.frame = CGRectMake(15, 0, timeWidth, height);
    
    // 2. 状态文字自适应宽度（优先保障其完整显示）
    [self.statusLabel sizeToFit];
    CGFloat statusWidth = self.statusLabel.bounds.size.width;
    if (statusWidth < 50) statusWidth = 50; // 保底宽度
    self.statusLabel.frame = CGRectMake(width - statusWidth - 15, 0, statusWidth, height);
    
    // 3. 节目名称使用剩余的弹性空间
    CGFloat titleX = CGRectGetMaxX(self.timeLabel.frame) + 10;
    CGFloat titleWidth = self.statusLabel.frame.origin.x - titleX - 10;
    self.titleMarqueeLabel.frame = CGRectMake(titleX, 0, titleWidth, height);
}

@end

#pragma mark - PlayerEPGView 主类

@interface PlayerEPGView () <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate>

@property (nonatomic, strong) UIView *dateContainerView;
// 拟物化增强：用于 iOS 6 的背景渐变层
@property (nonatomic, strong) CAGradientLayer *dateBarGradientLayer;
@property (nonatomic, strong) UIScrollView *dateScrollView;
@property (nonatomic, strong) UIView *indicatorLine;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) UITableView *tableView;

// 优化：新增空状态视图容器及占位图标
@property (nonatomic, strong) UIView *emptyStateContainer;
@property (nonatomic, strong) UILabel *emptyIconLabel;

@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) NSMutableArray *dateButtons;

@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSArray *availableDates;
@property (nonatomic, strong) NSDictionary *groupedPrograms;
@property (nonatomic, strong) NSArray *displayPrograms;
@property (nonatomic, strong) NSDate *selectedDate;
@property (nonatomic, copy) NSString *currentChannelName;

@property (nonatomic, strong) EPGProgram *lastPlayingProgram;

@property (nonatomic, strong) NSTimer *autoScrollTimer;

@property (nonatomic, assign) BOOL isIOS7;

@end

@implementation PlayerEPGView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        
        self.timeFormatter = [[NSDateFormatter alloc] init];
        [self.timeFormatter setTimeZone:[EPGManager sharedManager].epgTimeZone];
        [self.timeFormatter setDateFormat:@"HH:mm"];
        
        self.dateButtons = [NSMutableArray array];
        
        self.dateContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        if (self.isIOS7) {
            self.dateContainerView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.05];
        } else {
            // iOS 6 拟物化背景：银色金属感渐变
            self.dateBarGradientLayer = [CAGradientLayer layer];
            self.dateBarGradientLayer.colors = @[
                                                 (id)[UIColor colorWithWhite:0.95 alpha:1.0].CGColor,
                                                 (id)[UIColor colorWithWhite:0.80 alpha:1.0].CGColor,
                                                 (id)[UIColor colorWithWhite:0.75 alpha:1.0].CGColor
                                                 ];
            self.dateBarGradientLayer.locations = @[@0.0, @0.5, @1.0];
            [self.dateContainerView.layer addSublayer:self.dateBarGradientLayer];
        }
        [self addSubview:self.dateContainerView];
        
        self.dateScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        self.dateScrollView.showsHorizontalScrollIndicator = NO;
        self.dateScrollView.bounces = YES;
        self.dateScrollView.delegate = self;
        [self.dateContainerView addSubview:self.dateScrollView];
        
        self.indicatorLine = [[UIView alloc] initWithFrame:CGRectZero];
        if (self.isIOS7) {
            self.indicatorLine.backgroundColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
        } else {
            self.indicatorLine.backgroundColor = [UIColor orangeColor];
            // iOS 6 增加一点外发光和圆角，增加拟物感
            self.indicatorLine.layer.cornerRadius = 1.0;
            self.indicatorLine.layer.shadowColor = [UIColor orangeColor].CGColor;
            self.indicatorLine.layer.shadowOffset = CGSizeZero;
            self.indicatorLine.layer.shadowOpacity = 0.5;
            self.indicatorLine.layer.shadowRadius = 2.0;
        }
        [self.dateScrollView addSubview:self.indicatorLine];
        
        self.separatorLine = [[UIView alloc] initWithFrame:CGRectZero];
        self.separatorLine.backgroundColor = self.isIOS7 ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor darkGrayColor];
        [self.dateContainerView addSubview:self.separatorLine];
        
        self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.separatorColor = self.isIOS7 ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor darkGrayColor];
        if (self.isIOS7) {
            self.tableView.separatorInset = UIEdgeInsetsZero;
        }
        [self addSubview:self.tableView];
        
        // 美化：创建空状态容器
        self.emptyStateContainer = [[UIView alloc] initWithFrame:CGRectZero];
        self.emptyStateContainer.backgroundColor = [UIColor clearColor];
        self.emptyStateContainer.hidden = YES;
        [self addSubview:self.emptyStateContainer];
        
        // 美化：添加空状态图标
        self.emptyIconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.emptyIconLabel.backgroundColor = [UIColor clearColor];
        self.emptyIconLabel.textAlignment = NSTextAlignmentCenter;
        self.emptyIconLabel.font = [UIFont systemFontOfSize:50];
        [self.emptyStateContainer addSubview:self.emptyIconLabel];
        
        self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.tipsLabel.backgroundColor = [UIColor clearColor];
        self.tipsLabel.textAlignment = NSTextAlignmentCenter;
        self.tipsLabel.textColor = [UIColor darkGrayColor]; // 加深提示文字颜色
        self.tipsLabel.font = [UIFont systemFontOfSize:15]; // 调整提示文字大小
        self.tipsLabel.numberOfLines = 0;
        [self.emptyStateContainer addSubview:self.tipsLabel];
        
        self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        [self.actionButton setTitleColor:themeColor forState:UIControlStateNormal];
        self.actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:14]; // 加粗按钮文字
        self.actionButton.layer.borderColor = themeColor.CGColor;
        self.actionButton.layer.borderWidth = 1.0;
        self.actionButton.layer.cornerRadius = 16.0; // 药丸形状圆角美化
        self.actionButton.layer.masksToBounds = YES;
        self.actionButton.hidden = YES;
        [self.actionButton addTarget:self action:@selector(actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.emptyStateContainer addSubview:self.actionButton];
    }
    return self;
}

- (void)dealloc {
    [self stopAutoScrollTimer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat viewWidth = self.bounds.size.width;
    CGFloat viewHeight = self.bounds.size.height;
    
    self.dateContainerView.frame = CGRectMake(0, 0, viewWidth, 40);
    if (self.dateBarGradientLayer) {
        self.dateBarGradientLayer.frame = self.dateContainerView.bounds;
    }
    self.dateScrollView.frame = self.dateContainerView.bounds;
    self.separatorLine.frame = CGRectMake(0, 39, viewWidth, 1);
    
    self.tableView.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
    
    // 美化：重新布局空状态容器和内部元素，垂直居中排版
    self.emptyStateContainer.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
    CGFloat containerWidth = self.emptyStateContainer.bounds.size.width;
    CGFloat containerHeight = self.emptyStateContainer.bounds.size.height;
    
    self.emptyIconLabel.frame = CGRectMake(0, containerHeight / 2.0 - 70, containerWidth, 60);
    self.tipsLabel.frame = CGRectMake(20, containerHeight / 2.0 - 5, containerWidth - 40, 40);
    self.actionButton.frame = CGRectMake((containerWidth - 120) / 2.0, containerHeight / 2.0 + 45, 120, 32);
}

- (void)setReplayingProgram:(EPGProgram *)replayingProgram {
    _replayingProgram = replayingProgram;
    [self.tableView reloadData];
    [self scrollToCurrentProgram];
    [self startAutoScrollTimer];
}

- (void)actionButtonTapped:(UIButton *)sender {
    if (sender.tag == 1 && [self.delegate respondsToSelector:@selector(epgViewDidTapSettings:)]) {
        [self.delegate epgViewDidTapSettings:self];
    } else if (sender.tag == 2 && [self.delegate respondsToSelector:@selector(epgViewDidTapRefresh:)]) {
        [self.delegate epgViewDidTapRefresh:self];
    }
}

- (void)reloadData {
    BOOL isEPGEnabled = [EPGManager sharedManager].isEPGEnabled;
    NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
    
    if (![self.currentChannelName isEqualToString:epgSearchName]) {
        self.currentChannelName = epgSearchName;
        self.availableDates = nil;
        self.groupedPrograms = nil;
        self.selectedDate = nil;
        self.lastPlayingProgram = nil;
        [self.dateScrollView setContentOffset:CGPointZero animated:NO];
        [self stopAutoScrollTimer];
    }
    
    if (!isEPGEnabled) {
        self.emptyStateContainer.hidden = NO;
        self.emptyIconLabel.text = @"📺"; // 未开启图标
        self.tipsLabel.text = LocalizedString(@"epg_not_enabled");
        [self.actionButton setTitle:LocalizedString(@"go_to_settings") forState:UIControlStateNormal];
        self.actionButton.tag = 1;
        self.actionButton.hidden = NO;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
        
        self.displayPrograms = @[];
        [self.tableView reloadData];
        return;
    }
    
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        self.emptyStateContainer.hidden = YES;
        self.dateContainerView.hidden = NO;
        self.tableView.hidden = NO;
        
        if (!self.availableDates) {
            NSDate *today = [self startOfDayForDate:[NSDate date]];
            NSMutableArray *dates = [NSMutableArray array];
            for (int i = -5; i <= 1; i++) {
                [dates addObject:[today dateByAddingTimeInterval:i * 86400]];
            }
            self.availableDates = [dates copy];
            self.groupedPrograms = [NSMutableDictionary dictionary];
            [self buildDateBarUI];
            self.selectedDate = today;
            [self highlightDateButtonAtIndex:5 animated:NO];
        }
        [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
        return;
    }
    
    NSArray *allPrograms = @[];
    if (isEPGEnabled) {
        NSArray *fetched = [[EPGManager sharedManager] programsForChannelName:epgSearchName];
        if (fetched) allPrograms = fetched;
    }
    
    BOOL isExpired = YES;
    NSDate *now = [NSDate date];
    if (allPrograms.count > 0) {
        for (EPGProgram *p in allPrograms) {
            if ([p.endTime compare:now] == NSOrderedDescending) {
                isExpired = NO;
                break;
            }
        }
    }
    
    if (allPrograms.count == 0) {
        self.emptyStateContainer.hidden = NO;
        self.emptyIconLabel.text = @"📭"; // 空数据图标
        self.tipsLabel.text = LocalizedString(@"no_epg_data");
        self.actionButton.hidden = YES;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    if (isExpired) {
        self.emptyStateContainer.hidden = NO;
        self.emptyIconLabel.text = @"⏳"; // 过期图标
        self.tipsLabel.text = LocalizedString(@"epg_expired");
        [self.actionButton setTitle:LocalizedString(@"refresh_now") forState:UIControlStateNormal];
        self.actionButton.tag = 2;
        self.actionButton.hidden = NO;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    self.emptyStateContainer.hidden = YES;
    self.dateContainerView.hidden = NO;
    self.tableView.hidden = NO;
    
    NSMutableDictionary *grouped = [NSMutableDictionary dictionary];
    for (EPGProgram *p in allPrograms) {
        NSDate *dayStart = [self startOfDayForDate:p.startTime];
        NSMutableArray *dayPrograms = grouped[dayStart];
        if (!dayPrograms) {
            dayPrograms = [NSMutableArray array];
            grouped[(id<NSCopying>)dayStart] = dayPrograms;
        }
        [dayPrograms addObject:p];
    }
    self.groupedPrograms = grouped;
    self.availableDates = [[grouped allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    [self buildDateBarUI];
    
    if (self.availableDates.count > 0) {
        NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
        NSUInteger todayIndex = [self.availableDates indexOfObject:todayStart];
        if (todayIndex != NSNotFound) {
            self.selectedDate = todayStart;
            [self highlightDateButtonAtIndex:todayIndex animated:NO];
        } else {
            self.selectedDate = self.availableDates.firstObject;
            [self highlightDateButtonAtIndex:0 animated:NO];
        }
        self.displayPrograms = self.groupedPrograms[self.selectedDate];
        self.emptyStateContainer.hidden = YES;
        self.dateContainerView.hidden = NO;
        self.tableView.hidden = NO;
    } else {
        self.displayPrograms = @[];
        self.selectedDate = nil;
        self.emptyStateContainer.hidden = NO;
        self.emptyIconLabel.text = @"📭";
        self.tipsLabel.text = LocalizedString(@"no_epg_data");
        self.actionButton.hidden = YES;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
    }
    
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollToCurrentProgram];
        [self startAutoScrollTimer];
    });
}

// 修复：提取复位和滚动逻辑，当获取完数据后，如果在看今天则滚动中间，在看别天则停留在顶部
- (void)handleScrollAfterDataLoadForDate:(NSDate *)date {
    NSDate *targetDate = self.replayingProgram ? [self startOfDayForDate:self.replayingProgram.startTime] : [self startOfDayForDate:[NSDate date]];
    
    if ([date isEqualToDate:targetDate]) {
        [self scrollToCurrentProgram];
    } else {
        if (self.displayPrograms.count > 0) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
    }
}

- (void)fetchAndDisplayDynamicEPGForDate:(NSDate *)date channel:(NSString *)channelName {
    if (self.groupedPrograms[date]) {
        self.displayPrograms = self.groupedPrograms[date];
        if (self.displayPrograms.count > 0) {
            self.emptyStateContainer.hidden = YES;
        } else {
            self.emptyStateContainer.hidden = NO;
            self.emptyIconLabel.text = @"📭";
            self.tipsLabel.text = LocalizedString(@"no_epg_data");
            self.actionButton.hidden = YES;
        }
        [self.tableView reloadData];
        
        [self handleScrollAfterDataLoadForDate:date];
        [self startAutoScrollTimer];
    } else {
        self.displayPrograms = @[];
        [self.tableView reloadData];
        
        // 优化：显示加载状态的美化界面
        self.emptyStateContainer.hidden = NO;
        self.emptyIconLabel.text = @"📡"; // 加载中图标
        self.tipsLabel.text = LocalizedString(@"loading");
        self.actionButton.hidden = YES;
        
        __weak typeof(self) weakSelf = self;
        [[EPGManager sharedManager] fetchDynamicProgramsForChannelName:channelName date:date completion:^(NSArray *programs) {
            if ([weakSelf.currentChannelName isEqualToString:channelName] && [weakSelf.selectedDate isEqualToDate:date]) {
                NSMutableDictionary *mut = [weakSelf.groupedPrograms mutableCopy] ?: [NSMutableDictionary dictionary];
                mut[date] = programs ?: @[];
                weakSelf.groupedPrograms = mut;
                weakSelf.displayPrograms = mut[date];
                
                if (weakSelf.displayPrograms.count == 0) {
                    weakSelf.emptyStateContainer.hidden = NO;
                    weakSelf.emptyIconLabel.text = @"📭";
                    weakSelf.tipsLabel.text = LocalizedString(@"no_epg_data");
                    weakSelf.actionButton.hidden = YES;
                } else {
                    weakSelf.emptyStateContainer.hidden = YES;
                }
                [weakSelf.tableView reloadData];
                
                [weakSelf handleScrollAfterDataLoadForDate:date];
                [weakSelf startAutoScrollTimer];
            }
        }];
    }
}

- (NSDate *)startOfDayForDate:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    [calendar setTimeZone:[EPGManager sharedManager].epgTimeZone];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:date];
    return [calendar dateFromComponents:components];
}

- (NSString *)friendlyTitleForDate:(NSDate *)date {
    NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
    NSTimeInterval diff = [date timeIntervalSinceDate:todayStart];
    int days = round(diff / 86400.0);
    
    if (days == 0) return LocalizedString(@"today");
    if (days == 1) return LocalizedString(@"tomorrow");
    if (days == 2) return LocalizedString(@"day_after_tomorrow");
    if (days == -1) return LocalizedString(@"yesterday");
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setTimeZone:[EPGManager sharedManager].epgTimeZone];
    [df setDateFormat:@"MM-dd"];
    return [df stringFromDate:date];
}

- (void)buildDateBarUI {
    for (UIButton *btn in self.dateButtons) {
        [btn removeFromSuperview];
    }
    [self.dateButtons removeAllObjects];
    
    CGFloat btnWidth = 65.0;
    CGFloat currentX = 5.0;
    
    // 针对性优化：iOS 6 采用深灰文字，iOS 7+ 采用扁平浅灰
    UIColor *normalTextColor = self.isIOS7 ? [UIColor darkGrayColor] : [UIColor colorWithWhite:0.2 alpha:1.0];
    UIColor *selectedTextColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
    
    for (NSInteger i = 0; i < self.availableDates.count; i++) {
        NSDate *date = self.availableDates[i];
        NSString *title = [self friendlyTitleForDate:date];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(currentX, 0, btnWidth, 40);
        btn.tag = i;
        btn.titleLabel.font = [UIFont systemFontOfSize:14];
        
        [btn setTitle:title forState:UIControlStateNormal];
        [btn setTitleColor:normalTextColor forState:UIControlStateNormal];
        [btn setTitleColor:selectedTextColor forState:UIControlStateSelected];
        
        // 针对性优化：iOS 6 增加按钮文字投影，模拟拟物感
        if (!self.isIOS7) {
            [btn setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.titleLabel.shadowOffset = CGSizeMake(0, 1);
        }
        
        [btn addTarget:self action:@selector(dateButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.dateScrollView addSubview:btn];
        [self.dateButtons addObject:btn];
        currentX += btnWidth;
    }
    self.dateScrollView.contentSize = CGSizeMake(currentX + 5.0, 40);
}

- (void)dateButtonTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSDate *tappedDate = self.availableDates[index];
    if ([self.selectedDate isEqualToDate:tappedDate]) return;
    
    self.selectedDate = tappedDate;
    [self highlightDateButtonAtIndex:index animated:YES];
    
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
        [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
    } else {
        self.displayPrograms = self.groupedPrograms[self.selectedDate];
        [self.tableView reloadData];
        
        [self handleScrollAfterDataLoadForDate:self.selectedDate];
    }
    
    [self startAutoScrollTimer];
}

- (void)highlightDateButtonAtIndex:(NSInteger)index animated:(BOOL)animated {
    for (UIButton *btn in self.dateButtons) {
        btn.selected = NO;
        btn.titleLabel.font = [UIFont systemFontOfSize:14];
    }
    UIButton *selectedBtn = self.dateButtons[index];
    selectedBtn.selected = YES;
    selectedBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    
    // 针对性优化：iOS 6 的指示条略细，增加一点精致感
    CGFloat indicatorHeight = self.isIOS7 ? 2.0 : 3.0;
    CGRect indicatorFrame = CGRectMake(selectedBtn.frame.origin.x + 10, 40 - indicatorHeight - 1, selectedBtn.bounds.size.width - 20, indicatorHeight);
    
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.indicatorLine.frame = indicatorFrame;
        } completion:nil];
    } else {
        self.indicatorLine.frame = indicatorFrame;
    }
    [self.dateScrollView scrollRectToVisible:selectedBtn.frame animated:animated];
}

#pragma mark - 自动回正功能核心实现

- (void)startAutoScrollTimer {
    [self stopAutoScrollTimer];
    NSInteger timeout = [EPGManager sharedManager].autoScrollTimeout;
    if (timeout > 0) {
        self.autoScrollTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(autoScrollTimerFired) userInfo:nil repeats:NO];
    }
}

- (void)stopAutoScrollTimer {
    if (self.autoScrollTimer) {
        [self.autoScrollTimer invalidate];
        self.autoScrollTimer = nil;
    }
}

// 修复：明确由定时器专门接管“跨天拉回”的任务
- (void)autoScrollTimerFired {
    if (self.availableDates.count == 0) return;
    
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    
    NSDate *targetDate = nil;
    if (self.replayingProgram) {
        targetDate = [self startOfDayForDate:self.replayingProgram.startTime];
    } else {
        targetDate = todayStart;
    }
    
    // 如果用户当前查看的日期不是“目标日期”，则跨天跳转回去
    if (![self.selectedDate isEqualToDate:targetDate]) {
        NSUInteger index = [self.availableDates indexOfObject:targetDate];
        if (index != NSNotFound) {
            self.selectedDate = targetDate;
            [self highlightDateButtonAtIndex:index animated:YES];
            
            if ([[EPGManager sharedManager] isDynamicEPGSource]) {
                NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
                // 请求数据完成后，依然会通过 handleScrollAfterDataLoadForDate 滚动居中
                [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
                return;
            } else {
                self.displayPrograms = self.groupedPrograms[self.selectedDate];
                [self.tableView reloadData];
                // 跨天跳转后立刻滚动归中
                [self scrollToCurrentProgram];
            }
        }
    } else {
        // 如果已经在目标日期，直接触发滚动归中
        [self scrollToCurrentProgram];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopAutoScrollTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self startAutoScrollTimer];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self startAutoScrollTimer];
}

// 修复：剥离跨天逻辑，此方法现专用于将当前页面内的目标节目对齐居中
- (void)scrollToCurrentProgram {
    if (self.displayPrograms.count == 0 || !self.selectedDate) return;
    
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    
    if (self.replayingProgram) {
        NSDate *replayDayStart = [self startOfDayForDate:self.replayingProgram.startTime];
        if (![self.selectedDate isEqualToDate:replayDayStart]) return; // 不再跨天跳转，交由定时器处理
        
        NSInteger currentIndex = -1;
        for (NSInteger i = 0; i < self.displayPrograms.count; i++) {
            EPGProgram *p = self.displayPrograms[i];
            if ([p.startTime isEqualToDate:self.replayingProgram.startTime]) {
                currentIndex = i;
                break;
            }
        }
        if (currentIndex >= 0 && currentIndex < self.displayPrograms.count) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        }
        return;
    }
    
    if (![self.selectedDate isEqualToDate:todayStart]) return; // 不再跨天跳转，交由定时器处理
    
    NSInteger currentIndex = -1;
    for (NSInteger i = 0; i < self.displayPrograms.count; i++) {
        EPGProgram *p = self.displayPrograms[i];
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            currentIndex = i;
            break;
        }
    }
    
    if (currentIndex >= 0 && currentIndex < self.displayPrograms.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (EPGProgram *)currentPlayingProgram {
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    NSDate *yesterdayStart = [todayStart dateByAddingTimeInterval:-86400];
    
    NSArray *programs = self.groupedPrograms[todayStart];
    for (EPGProgram *p in programs) {
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            return p;
        }
    }
    
    programs = self.groupedPrograms[yesterdayStart];
    for (EPGProgram *p in programs) {
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            return p;
        }
    }
    return nil;
}

- (EPGProgram *)nextPlayingProgram {
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    NSDate *yesterdayStart = [todayStart dateByAddingTimeInterval:-86400];
    
    NSArray *programs = self.groupedPrograms[todayStart];
    if (programs) {
        for (NSInteger i = 0; i < programs.count; i++) {
            EPGProgram *p = programs[i];
            if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
                if (i + 1 < programs.count) {
                    return programs[i + 1];
                }
                break;
            }
        }
    }
    
    programs = self.groupedPrograms[yesterdayStart];
    if (programs) {
        for (NSInteger i = 0; i < programs.count; i++) {
            EPGProgram *p = programs[i];
            if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
                if (i + 1 < programs.count) {
                    return programs[i + 1];
                } else {
                    NSArray *todayPrograms = self.groupedPrograms[todayStart];
                    return todayPrograms.firstObject;
                }
            }
        }
    }
    
    programs = self.groupedPrograms[todayStart];
    for (EPGProgram *p in programs) {
        if ([p.startTime compare:now] == NSOrderedDescending) {
            return p;
        }
    }
    return nil;
}

#pragma mark - Timer Tick (Auto Refresh)

- (void)updateTimeTick {
    if (self.displayPrograms.count == 0) return;
    
    NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
    if (![self.selectedDate isEqualToDate:todayStart]) return;
    
    EPGProgram *current = [self currentPlayingProgram];
    
    BOOL programChanged = NO;
    if (!self.lastPlayingProgram && current) {
        programChanged = YES;
    } else if (self.lastPlayingProgram && !current) {
        programChanged = YES;
    } else if (self.lastPlayingProgram && current) {
        if (![self.lastPlayingProgram.startTime isEqualToDate:current.startTime]) {
            programChanged = YES;
        }
    }
    
    if (programChanged) {
        self.lastPlayingProgram = current;
        [self.tableView reloadData];
        if (!self.tableView.isDragging && !self.tableView.isDecelerating && !self.dateScrollView.isDragging && !self.dateScrollView.isDecelerating) {
            [self scrollToCurrentProgram];
        }
    }
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayPrograms.count;
}

// 确保视图出现时跑马灯动画能够被正确触发，修复滑动时的动画重置问题
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[EPGProgramCell class]]) {
        [((EPGProgramCell *)cell).titleMarqueeLabel startAnimation];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EPGProgramCellId";
    // 替换为使用我们自定义的 EPGProgramCell
    EPGProgramCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[EPGProgramCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSString *timeString = [self.timeFormatter stringFromDate:program.startTime];
    
    // 赋值给自定义 Cell 中的控件
    cell.timeLabel.text = timeString;
    cell.titleMarqueeLabel.text = program.title;
    
    NSDate *now = [NSDate date];
    
    BOOL isReplayingThis = (self.replayingProgram && [program.startTime isEqualToDate:self.replayingProgram.startTime]);
    BOOL isCurrentlyLive = ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending);
    
    // 针对性优化：iOS 6 拟物化 Cell 样式适配
    if (!self.isIOS7) {
        // iOS 6 增加文字投影，增加层次感
        UIColor *shadowColor = [UIColor whiteColor];
        CGSize shadowOffset = CGSizeMake(0, 1);
        
        cell.timeLabel.shadowColor = shadowColor;
        cell.timeLabel.shadowOffset = shadowOffset;
        
        cell.titleMarqueeLabel.shadowColor = shadowColor;
        cell.titleMarqueeLabel.shadowOffset = shadowOffset;
        
        cell.statusLabel.shadowColor = shadowColor;
        cell.statusLabel.shadowOffset = shadowOffset;
    } else {
        cell.timeLabel.shadowColor = nil;
        cell.titleMarqueeLabel.shadowColor = nil;
        cell.statusLabel.shadowColor = nil;
    }
    
    // 字体复位
    UIFont *normalFont = [UIFont systemFontOfSize:14];
    UIFont *statusNormalFont = [UIFont systemFontOfSize:12];
    UIFont *boldFont = [UIFont boldSystemFontOfSize:15];
    
    if (isReplayingThis) {
        UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        cell.timeLabel.textColor = themeColor;
        cell.titleMarqueeLabel.textColor = themeColor;
        cell.statusLabel.textColor = themeColor;
        
        cell.statusLabel.text = LocalizedString(@"now_replaying");
        
        cell.timeLabel.font = boldFont;
        cell.titleMarqueeLabel.font = boldFont;
        cell.statusLabel.font = statusNormalFont;
    } else if (isCurrentlyLive) {
        if (self.replayingProgram != nil) {
            UIColor *grayColor = [UIColor darkGrayColor];
            cell.timeLabel.textColor = grayColor;
            cell.titleMarqueeLabel.textColor = grayColor;
            cell.statusLabel.textColor = grayColor;
            
            cell.statusLabel.text = LocalizedString(@"playback_paused");
            
            cell.timeLabel.font = normalFont;
            cell.titleMarqueeLabel.font = normalFont;
            cell.statusLabel.font = statusNormalFont;
        } else {
            UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
            cell.timeLabel.textColor = themeColor;
            cell.titleMarqueeLabel.textColor = themeColor;
            cell.statusLabel.textColor = themeColor;
            
            cell.statusLabel.text = LocalizedString(@"now_playing");
            
            cell.timeLabel.font = boldFont;
            cell.titleMarqueeLabel.font = boldFont;
            cell.statusLabel.font = statusNormalFont;
        }
    } else if ([now compare:program.endTime] != NSOrderedAscending) {
        UIColor *grayColor = [UIColor darkGrayColor];
        cell.timeLabel.textColor = grayColor;
        cell.titleMarqueeLabel.textColor = grayColor;
        cell.statusLabel.textColor = grayColor;
        
        cell.statusLabel.text = LocalizedString(@"already_played");
        
        cell.timeLabel.font = normalFont;
        cell.titleMarqueeLabel.font = normalFont;
        cell.statusLabel.font = statusNormalFont;
    } else {
        // 修改：统一使用黑色文字，解决 iOS6 系统下硬编码白色文字导致在白底背景不可见的 Bug
        UIColor *normalColor = [UIColor blackColor];
        cell.timeLabel.textColor = normalColor;
        cell.titleMarqueeLabel.textColor = normalColor;
        cell.statusLabel.textColor = normalColor;
        
        cell.statusLabel.text = LocalizedString(@"not_played");
        
        cell.timeLabel.font = normalFont;
        cell.titleMarqueeLabel.font = normalFont;
        cell.statusLabel.font = statusNormalFont;
    }
    
    if (self.supportsCatchup && ([now compare:program.startTime] != NSOrderedAscending)) {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.supportsCatchup) return;
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSDate *now = [NSDate date];
    if ([now compare:program.startTime] != NSOrderedAscending) {
        if ([self.delegate respondsToSelector:@selector(epgView:didSelectProgram:)]) {
            [self.delegate epgView:self didSelectProgram:program];
        }
        [self startAutoScrollTimer];
    }
}

@end