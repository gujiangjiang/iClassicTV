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

@interface PlayerEPGView () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UIView *dateContainerView;
@property (nonatomic, strong) UIScrollView *dateScrollView;
@property (nonatomic, strong) UIView *indicatorLine;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) NSMutableArray *dateButtons;

@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSArray *availableDates;
@property (nonatomic, strong) NSDictionary *groupedPrograms;
@property (nonatomic, strong) NSArray *displayPrograms;
@property (nonatomic, strong) NSDate *selectedDate;
@property (nonatomic, copy) NSString *currentChannelName;

// 新增：用于记录上一次检查时的正在播放节目，用于对比是否跨越了时间节点
@property (nonatomic, strong) EPGProgram *lastPlayingProgram;

@property (nonatomic, assign) BOOL isIOS7;

@end

@implementation PlayerEPGView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        
        // 优化：让列表展示时间时严格遵循配置的时区
        self.timeFormatter = [[NSDateFormatter alloc] init];
        [self.timeFormatter setTimeZone:[EPGManager sharedManager].epgTimeZone];
        [self.timeFormatter setDateFormat:@"HH:mm"];
        
        self.dateButtons = [NSMutableArray array];
        
        self.dateContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        self.dateContainerView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.05];
        [self addSubview:self.dateContainerView];
        
        self.dateScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        self.dateScrollView.showsHorizontalScrollIndicator = NO;
        self.dateScrollView.bounces = YES;
        [self.dateContainerView addSubview:self.dateScrollView];
        
        self.indicatorLine = [[UIView alloc] initWithFrame:CGRectZero];
        self.indicatorLine.backgroundColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
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
        
        self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.tipsLabel.backgroundColor = [UIColor clearColor];
        self.tipsLabel.textAlignment = NSTextAlignmentCenter;
        self.tipsLabel.textColor = [UIColor grayColor];
        self.tipsLabel.font = [UIFont systemFontOfSize:14];
        self.tipsLabel.text = LocalizedString(@"no_epg_data");
        self.tipsLabel.numberOfLines = 0;
        [self addSubview:self.tipsLabel];
        
        self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        [self.actionButton setTitleColor:themeColor forState:UIControlStateNormal];
        self.actionButton.titleLabel.font = [UIFont systemFontOfSize:14];
        self.actionButton.layer.borderColor = themeColor.CGColor;
        self.actionButton.layer.borderWidth = 1.0;
        self.actionButton.layer.cornerRadius = 4.0;
        self.actionButton.layer.masksToBounds = YES;
        self.actionButton.hidden = YES;
        [self.actionButton addTarget:self action:@selector(actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.actionButton];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat viewWidth = self.bounds.size.width;
    CGFloat viewHeight = self.bounds.size.height;
    
    self.dateContainerView.frame = CGRectMake(0, 0, viewWidth, 40);
    self.dateScrollView.frame = self.dateContainerView.bounds;
    self.separatorLine.frame = CGRectMake(0, 39, viewWidth, 1);
    
    self.tableView.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
    
    CGFloat listCenterY = 40 + (viewHeight - 40) / 2.0;
    self.tipsLabel.frame = CGRectMake(20, listCenterY - 35, viewWidth - 40, 30);
    self.actionButton.frame = CGRectMake((viewWidth - 100) / 2.0, listCenterY + 5, 100, 32);
}

- (void)setReplayingProgram:(EPGProgram *)replayingProgram {
    _replayingProgram = replayingProgram;
    [self.tableView reloadData];
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
    }
    
    if (!isEPGEnabled) {
        self.tipsLabel.text = LocalizedString(@"epg_not_enabled");
        self.tipsLabel.hidden = NO;
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
        self.tipsLabel.hidden = YES;
        self.actionButton.hidden = YES;
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
        self.tipsLabel.text = LocalizedString(@"no_epg_data");
        self.tipsLabel.hidden = NO;
        self.actionButton.hidden = YES;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    if (isExpired) {
        self.tipsLabel.text = LocalizedString(@"epg_expired");
        self.tipsLabel.hidden = NO;
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
    
    self.tipsLabel.hidden = YES;
    self.actionButton.hidden = YES;
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
        self.tipsLabel.hidden = YES;
        self.dateContainerView.hidden = NO;
        self.tableView.hidden = NO;
    } else {
        self.displayPrograms = @[];
        self.selectedDate = nil;
        self.tipsLabel.hidden = NO;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
    }
    
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollToCurrentProgram];
    });
}

- (void)fetchAndDisplayDynamicEPGForDate:(NSDate *)date channel:(NSString *)channelName {
    if (self.groupedPrograms[date]) {
        self.displayPrograms = self.groupedPrograms[date];
        self.tipsLabel.hidden = self.displayPrograms.count > 0 ? YES : NO;
        self.tipsLabel.text = self.displayPrograms.count > 0 ? @"" : LocalizedString(@"no_epg_data");
        [self.tableView reloadData];
        [self scrollToCurrentProgram];
    } else {
        self.displayPrograms = @[];
        [self.tableView reloadData];
        self.tipsLabel.text = LocalizedString(@"loading");
        self.tipsLabel.hidden = NO;
        
        __weak typeof(self) weakSelf = self;
        [[EPGManager sharedManager] fetchDynamicProgramsForChannelName:channelName date:date completion:^(NSArray *programs) {
            if ([weakSelf.currentChannelName isEqualToString:channelName] && [weakSelf.selectedDate isEqualToDate:date]) {
                NSMutableDictionary *mut = [weakSelf.groupedPrograms mutableCopy] ?: [NSMutableDictionary dictionary];
                mut[date] = programs ?: @[];
                weakSelf.groupedPrograms = mut;
                weakSelf.displayPrograms = mut[date];
                
                if (weakSelf.displayPrograms.count == 0) {
                    weakSelf.tipsLabel.text = LocalizedString(@"no_epg_data");
                    weakSelf.tipsLabel.hidden = NO;
                } else {
                    weakSelf.tipsLabel.hidden = YES;
                }
                [weakSelf.tableView reloadData];
                [weakSelf scrollToCurrentProgram];
            }
        }];
    }
}

// 优化：提取日期时，将比较轴设定为配置的时区，避免跨天导致数据错乱
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
    
    // 同样，这里的显示也需要指定为配置的时区
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
    
    UIColor *normalTextColor = self.isIOS7 ? [UIColor darkGrayColor] : [UIColor lightGrayColor];
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
        
        NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
        if ([self.selectedDate isEqualToDate:todayStart]) {
            [self scrollToCurrentProgram];
        } else {
            if (self.displayPrograms.count > 0) {
                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
        }
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
    CGRect indicatorFrame = CGRectMake(selectedBtn.frame.origin.x + 10, 37, selectedBtn.bounds.size.width - 20, 2);
    
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.indicatorLine.frame = indicatorFrame;
        } completion:nil];
    } else {
        self.indicatorLine.frame = indicatorFrame;
    }
    [self.dateScrollView scrollRectToVisible:selectedBtn.frame animated:animated];
}

- (void)scrollToCurrentProgram {
    if (self.displayPrograms.count == 0 || !self.selectedDate) return;
    
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    
    if (self.replayingProgram) {
        NSDate *replayDayStart = [self startOfDayForDate:self.replayingProgram.startTime];
        if (![self.selectedDate isEqualToDate:replayDayStart]) return;
        
        NSInteger currentIndex = -1;
        for (NSInteger i = 0; i < self.displayPrograms.count; i++) {
            EPGProgram *p = self.displayPrograms[i];
            if ([p.startTime isEqualToDate:self.replayingProgram.startTime]) {
                currentIndex = i;
                break;
            }
        }
        if (currentIndex >= 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        }
        return;
    }
    
    if (![self.selectedDate isEqualToDate:todayStart]) return;
    
    NSInteger currentIndex = -1;
    for (NSInteger i = 0; i < self.displayPrograms.count; i++) {
        EPGProgram *p = self.displayPrograms[i];
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            currentIndex = i;
            break;
        }
    }
    if (currentIndex >= 0) {
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
    
    // 只有当用户查看的是当天的节目单时，才自动滚动和刷新状态
    NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
    if (![self.selectedDate isEqualToDate:todayStart]) return;
    
    EPGProgram *current = [self currentPlayingProgram];
    
    // 判断是否跨越了节目时间节点
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
        [self scrollToCurrentProgram];
    }
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayPrograms.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EPGCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    }
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSString *timeString = [self.timeFormatter stringFromDate:program.startTime];
    cell.textLabel.text = [NSString stringWithFormat:@"%@   %@", timeString, program.title];
    
    NSDate *now = [NSDate date];
    
    BOOL isReplayingThis = (self.replayingProgram && [program.startTime isEqualToDate:self.replayingProgram.startTime]);
    BOOL isCurrentlyLive = ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending);
    
    if (isReplayingThis) {
        UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        cell.textLabel.textColor = themeColor;
        cell.detailTextLabel.textColor = themeColor;
        cell.detailTextLabel.text = LocalizedString(@"now_replaying");
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    } else if (isCurrentlyLive) {
        if (self.replayingProgram != nil) {
            cell.textLabel.textColor = [UIColor darkGrayColor];
            cell.detailTextLabel.textColor = [UIColor darkGrayColor];
            cell.detailTextLabel.text = LocalizedString(@"playback_paused");
            cell.textLabel.font = [UIFont systemFontOfSize:14];
        } else {
            UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
            cell.textLabel.textColor = themeColor;
            cell.detailTextLabel.textColor = themeColor;
            cell.detailTextLabel.text = LocalizedString(@"now_playing");
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        }
    } else if ([now compare:program.endTime] != NSOrderedAscending) {
        cell.textLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.text = LocalizedString(@"already_played");
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    } else {
        UIColor *normalColor = self.isIOS7 ? [UIColor blackColor] : [UIColor whiteColor];
        cell.textLabel.textColor = normalColor;
        cell.detailTextLabel.textColor = normalColor;
        cell.detailTextLabel.text = LocalizedString(@"not_played");
        cell.textLabel.font = [UIFont systemFontOfSize:14];
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
    }
}

@end