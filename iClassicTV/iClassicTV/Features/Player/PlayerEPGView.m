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

@interface PlayerEPGView () <UITableViewDelegate, UITableViewDataSource>

// UI 组件
@property (nonatomic, strong) UIView *dateContainerView;
@property (nonatomic, strong) UIScrollView *dateScrollView;
@property (nonatomic, strong) UIView *indicatorLine;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) NSMutableArray *dateButtons;

// 数据源
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSArray *availableDates;          // 存储所有可用的日期 (NSDate)
@property (nonatomic, strong) NSDictionary *groupedPrograms;    // 按日期分组的节目数据
@property (nonatomic, strong) NSArray *displayPrograms;         // 当前选中日期需要展示的节目
@property (nonatomic, strong) NSDate *selectedDate;             // 当前选中的日期

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
        // 注意：移除了 autoresizingMask，统一交由 layoutSubviews 精准计算坐标
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
    }
    return self;
}

// 关键修复：完全弃用自动拉伸，依靠每次视图尺寸变动时进行精准的坐标重绘
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
    
    // 提示文本居中放置
    self.tipsLabel.frame = CGRectMake(20, 60, viewWidth - 40, 40);
}

#pragma mark - 数据加载与处理

- (void)reloadData {
    NSArray *allPrograms = @[];
    if ([EPGManager sharedManager].isEPGEnabled) {
        NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
        NSArray *fetched = [[EPGManager sharedManager] programsForChannelName:epgSearchName];
        if (fetched) allPrograms = fetched;
    }
    
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
        
        // 尝试寻找“今天”，如果没找到，就默认选中数组的第一个日期
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
    
    // 5. 数据加载完成后执行滚动
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollToCurrentProgram];
    });
}

// 核心辅助方法：抹除时间(时分秒)，获取某天 00:00:00 的 NSDate，用于精准分组
- (NSDate *)startOfDayForDate:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:date];
    return [calendar dateFromComponents:components];
}

// 核心辅助方法：将日期格式化为人类易读的文本
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
    // 清理旧的按钮
    for (UIButton *btn in self.dateButtons) {
        [btn removeFromSuperview];
    }
    [self.dateButtons removeAllObjects];
    
    CGFloat btnWidth = 65.0;
    CGFloat currentX = 5.0; // 起始留白
    
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
        return; // 重复点击，不做处理
    }
    
    self.selectedDate = tappedDate;
    self.displayPrograms = self.groupedPrograms[self.selectedDate];
    [self.tableView reloadData];
    
    [self highlightDateButtonAtIndex:index animated:YES];
    
    // 如果点击的是“今天”，则滚动到当前节目；否则滚动到该天的顶部
    NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
    if ([self.selectedDate isEqualToDate:todayStart]) {
        [self scrollToCurrentProgram];
    } else {
        if (self.displayPrograms.count > 0) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
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
    selectedBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15]; // 选中时稍微加粗放大
    
    CGRect indicatorFrame = CGRectMake(selectedBtn.frame.origin.x + 10, 37, selectedBtn.bounds.size.width - 20, 2);
    
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.indicatorLine.frame = indicatorFrame;
        } completion:nil];
    } else {
        self.indicatorLine.frame = indicatorFrame;
    }
    
    // 确保选中的按钮在可视区域内
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
        // 将当前播放的节目滚动到居中位置
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
    cell.textLabel.text = program.title;
    cell.detailTextLabel.text = timeString;
    
    NSDate *now = [NSDate date];
    
    // 判断逻辑：当前时间 >= 开始时间 且 当前时间 < 结束时间
    if ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending) {
        // 正在播放，使用高亮颜色 (跟随 iOS 系统风格)
        UIColor *playingColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        cell.textLabel.textColor = playingColor;
        cell.detailTextLabel.textColor = playingColor;
        
        // 正在播放的节目名称加粗
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    } else if ([now compare:program.endTime] != NSOrderedAscending) {
        // 已播完的节目，置灰
        cell.textLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    } else {
        // 尚未播放的节目
        UIColor *normalColor = self.isIOS7 ? [UIColor blackColor] : [UIColor whiteColor];
        cell.textLabel.textColor = normalColor;
        cell.detailTextLabel.textColor = normalColor;
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

@end