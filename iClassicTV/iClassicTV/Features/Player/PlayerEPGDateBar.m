//
//  PlayerEPGDateBar.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGDateBar.h"
#import "LanguageManager.h"
#import "EPGManager.h"
#import <QuartzCore/QuartzCore.h>

@interface PlayerEPGDateBar () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *dateScrollView;
@property (nonatomic, strong) UIView *indicatorLine;
@property (nonatomic, strong) CAGradientLayer *dateBarGradientLayer;
@property (nonatomic, strong) NSMutableArray *dateButtons;
@property (nonatomic, strong) NSArray *availableDates;
@property (nonatomic, assign) BOOL isIOS7;
@end

@implementation PlayerEPGDateBar

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        self.dateButtons = [NSMutableArray array];
        
        if (self.isIOS7) {
            self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.05];
        } else {
            // iOS 6 拟物化背景：银色金属感渐变
            self.dateBarGradientLayer = [CAGradientLayer layer];
            self.dateBarGradientLayer.colors = @[
                                                 (id)[UIColor colorWithWhite:0.95 alpha:1.0].CGColor,
                                                 (id)[UIColor colorWithWhite:0.80 alpha:1.0].CGColor,
                                                 (id)[UIColor colorWithWhite:0.75 alpha:1.0].CGColor
                                                 ];
            self.dateBarGradientLayer.locations = @[@0.0, @0.5, @1.0];
            [self.layer addSublayer:self.dateBarGradientLayer];
        }
        
        self.dateScrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.dateScrollView.showsHorizontalScrollIndicator = NO;
        self.dateScrollView.bounces = YES;
        self.dateScrollView.delegate = self;
        [self addSubview:self.dateScrollView];
        
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
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.dateBarGradientLayer) {
        self.dateBarGradientLayer.frame = self.bounds;
    }
    self.dateScrollView.frame = self.bounds;
}

- (void)updateWithDates:(NSArray *)dates {
    self.availableDates = dates;
    [self buildDateBarUI];
}

- (void)resetScrollPosition {
    [self.dateScrollView setContentOffset:CGPointZero animated:NO];
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
    if ([self.delegate respondsToSelector:@selector(dateBar:didSelectDateAtIndex:)]) {
        [self.delegate dateBar:self didSelectDateAtIndex:sender.tag];
    }
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

#pragma mark - UIScrollViewDelegate 透传，用于主视图接管定时器

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([self.delegate respondsToSelector:@selector(dateBarWillBeginDragging:)]) {
        [self.delegate dateBarWillBeginDragging:self];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if ([self.delegate respondsToSelector:@selector(dateBarDidEndDragging:willDecelerate:)]) {
        [self.delegate dateBarDidEndDragging:self willDecelerate:decelerate];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if ([self.delegate respondsToSelector:@selector(dateBarDidEndDecelerating:)]) {
        [self.delegate dateBarDidEndDecelerating:self];
    }
}

@end