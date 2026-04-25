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

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) NSArray *epgPrograms;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;

@end

@implementation PlayerEPGView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        // 初始化时间格式化器，用于在列表中展示 HH:mm 格式的时间
        self.timeFormatter = [[NSDateFormatter alloc] init];
        [self.timeFormatter setDateFormat:@"HH:mm"];
        
        // EPG TableView 初始化
        self.tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        // iOS 6 分割线颜色调整，使其在深色背景下不显得突兀
        self.tableView.separatorColor = [UIColor darkGrayColor];
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
            self.tableView.separatorInset = UIEdgeInsetsZero;
        }
        [self addSubview:self.tableView];
        
        // 当没有 EPG 数据时用于展示空状态提示
        self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 30, self.bounds.size.width - 40, 40)];
        self.tipsLabel.backgroundColor = [UIColor clearColor];
        self.tipsLabel.textAlignment = NSTextAlignmentCenter;
        self.tipsLabel.textColor = [UIColor grayColor];
        self.tipsLabel.font = [UIFont systemFontOfSize:14];
        self.tipsLabel.text = @"暂无节目单数据";
        self.tipsLabel.numberOfLines = 0;
        self.tipsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.tipsLabel];
    }
    return self;
}

- (void)reloadData {
    // 获取当前频道的 EPG 数据
    if ([EPGManager sharedManager].isEPGEnabled) {
        // 优先使用 tvg-name 进行 EPG 匹配，若不存在或为空，则回退使用频道的显示名称 (channelTitle)
        NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
        NSArray *programs = [[EPGManager sharedManager] programsForChannelName:epgSearchName];
        self.epgPrograms = programs ? programs : @[];
    } else {
        self.epgPrograms = @[];
    }
    
    self.tipsLabel.hidden = (self.epgPrograms.count > 0);
    [self.tableView reloadData];
}

- (void)scrollToCurrentProgram {
    if (self.epgPrograms.count == 0) return;
    
    NSDate *now = [NSDate date];
    NSInteger currentIndex = -1;
    
    for (NSInteger i = 0; i < self.epgPrograms.count; i++) {
        EPGProgram *p = self.epgPrograms[i];
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            currentIndex = i;
            break;
        }
    }
    
    // 如果找到了当前正在播放的节目，自动滚动并将其居中显示
    if (currentIndex >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
}

#pragma mark - UITableViewDataSource & UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.epgPrograms.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EPGCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        // 使用 Value1 样式：左边节目名，右边时间
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.selectionStyle = UITableViewCellSelectionStyleNone; // 节目单只做展示，不可点击
    }
    
    EPGProgram *program = self.epgPrograms[indexPath.row];
    NSString *timeString = [self.timeFormatter stringFromDate:program.startTime];
    cell.textLabel.text = program.title;
    cell.detailTextLabel.text = timeString;
    
    NSDate *now = [NSDate date];
    // 判断逻辑：当前时间 >= 开始时间 且 当前时间 < 结束时间
    if ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending) {
        // 正在播放，使用醒目颜色高亮
        cell.textLabel.textColor = [UIColor orangeColor];
        cell.detailTextLabel.textColor = [UIColor orangeColor];
    } else if ([now compare:program.endTime] != NSOrderedAscending) {
        // 已播完的节目置灰
        cell.textLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    } else {
        // 未播放的节目，适配 iOS 6 与 iOS 7 的底色
        BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        UIColor *normalColor = isIOS7 ? [UIColor blackColor] : [UIColor whiteColor];
        cell.textLabel.textColor = normalColor;
        cell.detailTextLabel.textColor = normalColor;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

@end