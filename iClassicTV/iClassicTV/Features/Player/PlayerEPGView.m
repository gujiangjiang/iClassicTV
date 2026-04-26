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
#import "EPGProgramCell.h"
#import "PlayerEPGEmptyView.h"
#import "PlayerEPGDateBar.h"

@interface PlayerEPGView () <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, PlayerEPGEmptyViewDelegate, PlayerEPGDateBarDelegate>

@property (nonatomic, strong) PlayerEPGDateBar *dateBar;
@property (nonatomic, strong) PlayerEPGEmptyView *emptyView;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) UITableView *tableView;

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
        
        // 装载子模块：日期栏
        self.dateBar = [[PlayerEPGDateBar alloc] initWithFrame:CGRectZero];
        self.dateBar.delegate = self;
        [self addSubview:self.dateBar];
        
        self.separatorLine = [[UIView alloc] initWithFrame:CGRectZero];
        self.separatorLine.backgroundColor = self.isIOS7 ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor darkGrayColor];
        [self addSubview:self.separatorLine];
        
        // 装载子模块：列表视图 (修复层级问题：先添加列表视图，使其在底层)
        self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.separatorColor = self.isIOS7 ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor darkGrayColor];
        if (self.isIOS7) {
            self.tableView.separatorInset = UIEdgeInsetsZero;
        }
        [self addSubview:self.tableView];
        
        // 装载子模块：空状态视图 (修复层级问题：最后添加空视图，确保其位于最顶层，不会被列表遮挡)
        self.emptyView = [[PlayerEPGEmptyView alloc] initWithFrame:CGRectZero];
        self.emptyView.delegate = self;
        [self addSubview:self.emptyView];
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
    
    self.dateBar.frame = CGRectMake(0, 0, viewWidth, 40);
    self.separatorLine.frame = CGRectMake(0, 39, viewWidth, 1);
    self.tableView.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
    self.emptyView.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
}

- (void)setReplayingProgram:(EPGProgram *)replayingProgram {
    _replayingProgram = replayingProgram;
    [self.tableView reloadData];
    [self scrollToCurrentProgram];
    [self startAutoScrollTimer];
}

#pragma mark - PlayerEPGEmptyViewDelegate

- (void)emptyViewDidTapSettings {
    if ([self.delegate respondsToSelector:@selector(epgViewDidTapSettings:)]) {
        [self.delegate epgViewDidTapSettings:self];
    }
}

- (void)emptyViewDidTapRefresh {
    // [优化] 如果是动态接口（DIYP / EPGInfo），点击按钮时只请求当前频道，而不是全量更新XML
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
        NSDate *targetDate = self.selectedDate ?: [self startOfDayForDate:[NSDate date]];
        
        // 修复：重试前先清除当前日期的错误缓存（如空数组），强制触发重新网络请求，否则依然显示无数据
        if (self.groupedPrograms[targetDate]) {
            NSMutableDictionary *mut = [self.groupedPrograms mutableCopy];
            [mut removeObjectForKey:targetDate];
            self.groupedPrograms = mut;
        }
        
        [self fetchAndDisplayDynamicEPGForDate:targetDate channel:epgSearchName];
    } else {
        if ([self.delegate respondsToSelector:@selector(epgViewDidTapRefresh:)]) {
            [self.delegate epgViewDidTapRefresh:self];
        }
    }
}

#pragma mark - Data Loading

- (void)reloadData {
    BOOL isEPGEnabled = [EPGManager sharedManager].isEPGEnabled;
    NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
    
    // 每次重载数据前，将当前数据源类型传递给 EmptyView，以便其更新按钮文案
    self.emptyView.isDynamicSource = [[EPGManager sharedManager] isDynamicEPGSource];
    
    if (![self.currentChannelName isEqualToString:epgSearchName]) {
        self.currentChannelName = epgSearchName;
        self.availableDates = nil;
        self.groupedPrograms = nil;
        self.selectedDate = nil;
        self.lastPlayingProgram = nil;
        [self.dateBar resetScrollPosition];
        [self stopAutoScrollTimer];
    }
    
    if (!isEPGEnabled) {
        [self.emptyView setState:EPGEmptyStateTypeNotEnabled];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        [self.tableView reloadData];
        return;
    }
    
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        self.dateBar.hidden = NO;
        self.separatorLine.hidden = NO;
        self.tableView.hidden = NO;
        
        if (!self.availableDates) {
            NSDate *today = [self startOfDayForDate:[NSDate date]];
            NSMutableArray *dates = [NSMutableArray array];
            for (int i = -5; i <= 1; i++) {
                [dates addObject:[today dateByAddingTimeInterval:i * 86400]];
            }
            self.availableDates = [dates copy];
            self.groupedPrograms = [NSMutableDictionary dictionary];
            [self.dateBar updateWithDates:self.availableDates];
            self.selectedDate = today;
            [self.dateBar highlightDateButtonAtIndex:5 animated:NO];
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
        [self.emptyView setState:EPGEmptyStateTypeNoData];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    if (isExpired) {
        [self.emptyView setState:EPGEmptyStateTypeExpired];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    self.dateBar.hidden = NO;
    self.separatorLine.hidden = NO;
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
    
    [self.dateBar updateWithDates:self.availableDates];
    
    if (self.availableDates.count > 0) {
        NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
        NSUInteger todayIndex = [self.availableDates indexOfObject:todayStart];
        if (todayIndex != NSNotFound) {
            self.selectedDate = todayStart;
            [self.dateBar highlightDateButtonAtIndex:todayIndex animated:NO];
        } else {
            self.selectedDate = self.availableDates.firstObject;
            [self.dateBar highlightDateButtonAtIndex:0 animated:NO];
        }
        self.displayPrograms = self.groupedPrograms[self.selectedDate];
        [self.emptyView setState:EPGEmptyStateTypeNone];
        self.tableView.hidden = NO;
    } else {
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.emptyView setState:EPGEmptyStateTypeNoData];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
    }
    
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollToCurrentProgram];
        [self startAutoScrollTimer];
    });
}

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
            [self.emptyView setState:EPGEmptyStateTypeNone];
            self.tableView.hidden = NO;
        } else {
            [self.emptyView setState:EPGEmptyStateTypeNoData];
            self.tableView.hidden = YES;
        }
        [self.tableView reloadData];
        [self handleScrollAfterDataLoadForDate:date];
        [self startAutoScrollTimer];
    } else {
        self.displayPrograms = @[];
        [self.tableView reloadData];
        
        // 修复：当进入加载中状态时，必须彻底隐藏底层的列表，防止空列表的分割线透出遮挡 Emoji 图标
        self.tableView.hidden = YES;
        [self.emptyView setState:EPGEmptyStateTypeLoading];
        
        __weak typeof(self) weakSelf = self;
        [[EPGManager sharedManager] fetchDynamicProgramsForChannelName:channelName date:date completion:^(NSArray *programs) {
            if ([weakSelf.currentChannelName isEqualToString:channelName] && [weakSelf.selectedDate isEqualToDate:date]) {
                
                // [修复] 防脏数据覆盖机制：如果拉取回来的数据为空，并且本地已经有当天的有效缓存，则直接丢弃空数据，不执行覆盖！
                NSArray *existingData = weakSelf.groupedPrograms[date];
                if ((!programs || programs.count == 0) && existingData && existingData.count > 0) {
                    // 沿用旧数据，跳过覆盖操作，恢复UI状态
                    weakSelf.displayPrograms = existingData;
                    [weakSelf.emptyView setState:EPGEmptyStateTypeNone];
                    weakSelf.tableView.hidden = NO;
                    [weakSelf.tableView reloadData];
                    return;
                }
                
                NSMutableDictionary *mut = [weakSelf.groupedPrograms mutableCopy] ?: [NSMutableDictionary dictionary];
                mut[date] = programs ?: @[];
                weakSelf.groupedPrograms = mut;
                weakSelf.displayPrograms = mut[date];
                
                if (weakSelf.displayPrograms.count == 0) {
                    [weakSelf.emptyView setState:EPGEmptyStateTypeNoData];
                    weakSelf.tableView.hidden = YES;
                } else {
                    [weakSelf.emptyView setState:EPGEmptyStateTypeNone];
                    weakSelf.tableView.hidden = NO;
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

#pragma mark - PlayerEPGDateBarDelegate

- (void)dateBar:(PlayerEPGDateBar *)dateBar didSelectDateAtIndex:(NSInteger)index {
    NSDate *tappedDate = self.availableDates[index];
    if ([self.selectedDate isEqualToDate:tappedDate]) return;
    
    self.selectedDate = tappedDate;
    [self.dateBar highlightDateButtonAtIndex:index animated:YES];
    
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

// 日期横向滚动时，透传给主视图并暂停自动回正定时器
- (void)dateBarWillBeginDragging:(PlayerEPGDateBar *)dateBar {
    [self stopAutoScrollTimer];
}

- (void)dateBarDidEndDragging:(PlayerEPGDateBar *)dateBar willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self startAutoScrollTimer];
}

- (void)dateBarDidEndDecelerating:(PlayerEPGDateBar *)dateBar {
    [self startAutoScrollTimer];
}

#pragma mark - Auto Scroll

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

- (void)autoScrollTimerFired {
    if (self.availableDates.count == 0) return;
    
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    NSDate *targetDate = self.replayingProgram ? [self startOfDayForDate:self.replayingProgram.startTime] : todayStart;
    
    if (![self.selectedDate isEqualToDate:targetDate]) {
        NSUInteger index = [self.availableDates indexOfObject:targetDate];
        if (index != NSNotFound) {
            self.selectedDate = targetDate;
            [self.dateBar highlightDateButtonAtIndex:index animated:YES];
            
            if ([[EPGManager sharedManager] isDynamicEPGSource]) {
                NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
                [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
                return;
            } else {
                self.displayPrograms = self.groupedPrograms[self.selectedDate];
                [self.tableView reloadData];
                [self scrollToCurrentProgram];
            }
        }
    } else {
        [self scrollToCurrentProgram];
    }
}

// 节目竖向列表滚动时，暂停定时器
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopAutoScrollTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self startAutoScrollTimer];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self startAutoScrollTimer];
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
        if (currentIndex >= 0 && currentIndex < self.displayPrograms.count) {
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
                if (i + 1 < programs.count) return programs[i + 1];
                break;
            }
        }
    }
    
    programs = self.groupedPrograms[yesterdayStart];
    if (programs) {
        for (NSInteger i = 0; i < programs.count; i++) {
            EPGProgram *p = programs[i];
            if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
                if (i + 1 < programs.count) return programs[i + 1];
                else return [self.groupedPrograms[todayStart] firstObject];
            }
        }
    }
    
    for (EPGProgram *p in self.groupedPrograms[todayStart]) {
        if ([p.startTime compare:now] == NSOrderedDescending) return p;
    }
    return nil;
}

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
        // 此处的 isDragging 检查是为了确保不会打断用户的拖动手势
        if (!self.tableView.isDragging && !self.tableView.isDecelerating) {
            [self scrollToCurrentProgram];
        }
    }
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayPrograms.count;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[EPGProgramCell class]]) {
        [((EPGProgramCell *)cell).titleMarqueeLabel startAnimation];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EPGProgramCellId";
    EPGProgramCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[EPGProgramCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSString *timeString = [self.timeFormatter stringFromDate:program.startTime];
    
    cell.timeLabel.text = timeString;
    cell.titleMarqueeLabel.text = program.title;
    
    NSDate *now = [NSDate date];
    
    BOOL isReplayingThis = (self.replayingProgram && [program.startTime isEqualToDate:self.replayingProgram.startTime]);
    BOOL isCurrentlyLive = ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending);
    
    // 针对性优化：iOS 6 拟物化 Cell 样式适配
    if (!self.isIOS7) {
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