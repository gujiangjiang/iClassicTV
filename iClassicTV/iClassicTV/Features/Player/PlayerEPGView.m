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
#import <QuartzCore/QuartzCore.h> // 用于按钮的边框圆角设置

@interface PlayerEPGView () <UITableViewDelegate, UITableViewDataSource>

// UI 组件
@property (nonatomic, strong) UIView *dateContainerView;
@property (nonatomic, strong) UIScrollView *dateScrollView;
@property (nonatomic, strong) UIView *indicatorLine;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) UIButton *actionButton; // 空状态下的操作按钮
@property (nonatomic, strong) NSMutableArray *dateButtons;

// 数据源
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSArray *availableDates;          // 存储所有可用的日期 (NSDate)
@property (nonatomic, strong) NSDictionary *groupedPrograms;    // 按日期分组的节目数据
@property (nonatomic, strong) NSArray *displayPrograms;         // 当前选中日期需要展示的节目
@property (nonatomic, strong) NSDate *selectedDate;             // 当前选中的日期
@property (nonatomic, copy) NSString *currentChannelName;       // 记录当前正在查的频道名

// 系统主题适配标识
@property (nonatomic, assign) BOOL isIOS7;

@end

@implementation PlayerEPGView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        
        // 1. 初始化时间格式化器
        self.timeFormatter = [[NSDateFormatter alloc] init];
        [self.timeFormatter setDateFormat:@"HH:mm"];
        
        self.dateButtons = [NSMutableArray array];
        
        // 2. 顶部的日期选择容器
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
        
        // 3. 底部的节目列表
        self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.separatorColor = self.isIOS7 ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor darkGrayColor];
        if (self.isIOS7) {
            self.tableView.separatorInset = UIEdgeInsetsZero;
        }
        [self addSubview:self.tableView];
        
        // 4. 空状态提示
        self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.tipsLabel.backgroundColor = [UIColor clearColor];
        self.tipsLabel.textAlignment = NSTextAlignmentCenter;
        self.tipsLabel.textColor = [UIColor grayColor];
        self.tipsLabel.font = [UIFont systemFontOfSize:14];
        self.tipsLabel.text = @"暂无节目单数据";
        self.tipsLabel.numberOfLines = 0;
        [self addSubview:self.tipsLabel];
        
        // 5. 操作按钮（用于跳转设置或立即刷新）
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
    
    // 顶部日期栏固定 40 高度
    self.dateContainerView.frame = CGRectMake(0, 0, viewWidth, 40);
    self.dateScrollView.frame = self.dateContainerView.bounds;
    self.separatorLine.frame = CGRectMake(0, 39, viewWidth, 1);
    
    // 列表从 40 开始，占据余下的所有高度
    self.tableView.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
    
    // 提示文本和操作按钮居中放置
    CGFloat listCenterY = 40 + (viewHeight - 40) / 2.0;
    self.tipsLabel.frame = CGRectMake(20, listCenterY - 35, viewWidth - 40, 30);
    self.actionButton.frame = CGRectMake((viewWidth - 100) / 2.0, listCenterY + 5, 100, 32);
}

#pragma mark - 按钮操作事件

- (void)actionButtonTapped:(UIButton *)sender {
    if (sender.tag == 1 && [self.delegate respondsToSelector:@selector(epgViewDidTapSettings:)]) {
        [self.delegate epgViewDidTapSettings:self];
    } else if (sender.tag == 2 && [self.delegate respondsToSelector:@selector(epgViewDidTapRefresh:)]) {
        [self.delegate epgViewDidTapRefresh:self];
    }
}

#pragma mark - 数据加载与处理

- (void)reloadData {
    BOOL isEPGEnabled = [EPGManager sharedManager].isEPGEnabled;
    NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
    
    // 频道切换时重置界面状态
    if (![self.currentChannelName isEqualToString:epgSearchName]) {
        self.currentChannelName = epgSearchName;
        self.availableDates = nil;
        self.groupedPrograms = nil;
        self.selectedDate = nil;
        [self.dateScrollView setContentOffset:CGPointZero animated:NO];
    }
    
    // 状态 1：未开启电子节目单
    if (!isEPGEnabled) {
        self.tipsLabel.text = @"未开启电子节目单";
        self.tipsLabel.hidden = NO;
        [self.actionButton setTitle:@"去设置" forState:UIControlStateNormal];
        self.actionButton.tag = 1;
        self.actionButton.hidden = NO;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
        
        self.displayPrograms = @[];
        [self.tableView reloadData];
        return;
    }
    
    // --- 动态请求类型处理 ---
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        self.tipsLabel.hidden = YES;
        self.actionButton.hidden = YES; // 动态请求无需显示刷新/设置按钮
        self.dateContainerView.hidden = NO;
        self.tableView.hidden = NO;
        
        // 动态源默认构建 7 天时间栏 (前推5天, 昨天, 今天, 明天)
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
            [self highlightDateButtonAtIndex:5 animated:NO]; // 默认高亮今天 (index 5)
        }
        
        [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
        return;
    }
    
    // --- XML静态数据解析 ---
    NSArray *allPrograms = @[];
    if (isEPGEnabled) {
        NSArray *fetched = [[EPGManager sharedManager] programsForChannelName:epgSearchName];
        if (fetched) allPrograms = fetched;
    }
    
    // 检查是否过期：如果所有节目的结束时间都早于当前时间，则视为已过期
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
    
    // 状态 2：开启了但暂无匹配的节目单数据
    if (allPrograms.count == 0) {
        self.tipsLabel.text = @"暂无节目单数据";
        self.tipsLabel.hidden = NO;
        self.actionButton.hidden = YES;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
        
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    // 状态 3：开启了且有节目单，但所有节目均已过期
    if (isExpired) {
        self.tipsLabel.text = @"节目单已过期";
        self.tipsLabel.hidden = NO;
        [self.actionButton setTitle:@"立即刷新" forState:UIControlStateNormal];
        self.actionButton.tag = 2;
        self.actionButton.hidden = NO;
        self.dateContainerView.hidden = YES;
        self.tableView.hidden = YES;
        
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    // 正常状态：隐藏提示并正常渲染
    self.tipsLabel.hidden = YES;
    self.actionButton.hidden = YES;
    self.dateContainerView.hidden = NO;
    self.tableView.hidden = NO;
    
    // 1. 将节目按“自然日”进行分组
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
    
    // 2. 提取所有有节目的日期并排序
    self.availableDates = [[grouped allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    // 3. 构建顶部的日期 UI
    [self buildDateBarUI];
    
    // 4. 判断并设置默认选中的日期
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

// 动态提取获取并展示某日数据的业务块
- (void)fetchAndDisplayDynamicEPGForDate:(NSDate *)date channel:(NSString *)channelName {
    if (self.groupedPrograms[date]) {
        self.displayPrograms = self.groupedPrograms[date];
        self.tipsLabel.hidden = self.displayPrograms.count > 0 ? YES : NO;
        self.tipsLabel.text = self.displayPrograms.count > 0 ? @"" : @"暂无节目单数据";
        [self.tableView reloadData];
        [self scrollToCurrentProgram];
    } else {
        self.displayPrograms = @[];
        [self.tableView reloadData];
        self.tipsLabel.text = @"加载中...";
        self.tipsLabel.hidden = NO;
        
        __weak typeof(self) weakSelf = self;
        [[EPGManager sharedManager] fetchDynamicProgramsForChannelName:channelName date:date completion:^(NSArray *programs) {
            // 确保网络回调时依然在当前频道以及这个日期视图下
            if ([weakSelf.currentChannelName isEqualToString:channelName] && [weakSelf.selectedDate isEqualToDate:date]) {
                NSMutableDictionary *mut = [weakSelf.groupedPrograms mutableCopy] ?: [NSMutableDictionary dictionary];
                mut[date] = programs ?: @[];
                weakSelf.groupedPrograms = mut;
                weakSelf.displayPrograms = mut[date];
                
                if (weakSelf.displayPrograms.count == 0) {
                    weakSelf.tipsLabel.text = @"暂无节目单数据";
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

// 抹除时间(时分秒)，获取某天 00:00:00 的 NSDate
- (NSDate *)startOfDayForDate:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:date];
    return [calendar dateFromComponents:components];
}

// 将日期格式化为人类易读的文本
- (NSString *)friendlyTitleForDate:(NSDate *)date {
    NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
    NSTimeInterval diff = [date timeIntervalSinceDate:todayStart];
    int days = round(diff / 86400.0); // 86400秒 = 1天
    
    if (days == 0) return @"今天";
    if (days == 1) return @"明天";
    if (days == 2) return @"后天";
    if (days == -1) return @"昨天";
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"MM-dd"];
    return [df stringFromDate:date];
}

#pragma mark - 顶部日期栏 UI 构建

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

// 日期点击事件
- (void)dateButtonTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSDate *tappedDate = self.availableDates[index];
    
    if ([self.selectedDate isEqualToDate:tappedDate]) {
        return;
    }
    
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

// 负责高亮指定的按钮，并执行底部指示器的平滑过渡动画
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

#pragma mark - 自动滚动逻辑

- (void)scrollToCurrentProgram {
    if (self.displayPrograms.count == 0 || !self.selectedDate) return;
    
    // 只有当目前展示的是“今天”的数据时，才执行时间匹配滚动
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    
    if (![self.selectedDate isEqualToDate:todayStart]) {
        return;
    }
    
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

#pragma mark - UITableViewDataSource & UITableViewDelegate

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
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSString *timeString = [self.timeFormatter stringFromDate:program.startTime];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@   %@", timeString, program.title];
    
    NSDate *now = [NSDate date];
    
    if ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending) {
        // 正在播放
        UIColor *playingColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        cell.textLabel.textColor = playingColor;
        cell.detailTextLabel.textColor = playingColor;
        cell.detailTextLabel.text = @"正在播放";
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    } else if ([now compare:program.endTime] != NSOrderedAscending) {
        // 已播完
        cell.textLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.text = @"已播放";
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    } else {
        // 未播放
        UIColor *normalColor = self.isIOS7 ? [UIColor blackColor] : [UIColor whiteColor];
        cell.textLabel.textColor = normalColor;
        cell.detailTextLabel.textColor = normalColor;
        cell.detailTextLabel.text = @"未播放";
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

@end