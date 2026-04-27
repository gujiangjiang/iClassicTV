//
//  WatchListReminderViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "WatchListReminderViewController.h"
#import "WatchListDataManager.h"
#import "LanguageManager.h"
#import "TVPlaybackViewController.h" // [新增]
#import "AppDataManager.h"           // [新增]
#import "M3UParser.h"                // [新增]
#import "Channel.h"                  // [新增]
#import "ToastHelper.h"              // [新增]
#import "PlayerConfigManager.h"      // [新增] 引入以获取当前记录模式

@interface WatchListReminderViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *groupedKeys;      // 存储分组依据：ChannelName
@property (nonatomic, strong) NSMutableDictionary *groupedData; // 存储各分组对应的预约记录数组

@end

@implementation WatchListReminderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 适配 iOS 7+ 视图布局
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadData) name:@"WatchListDataDidChangeNotification" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// [新增] 加载、过滤并按频道对数据进行分组
- (void)loadData {
    // 每次显示前都清理一波已过期的历史预约
    [[WatchListDataManager sharedManager] filterExpiredAppointments];
    
    NSArray *arr = [[WatchListDataManager sharedManager] getAppointments];
    self.groupedKeys = [NSMutableArray array];
    self.groupedData = [NSMutableDictionary dictionary];
    
    for (NSDictionary *info in arr) {
        NSString *channel = info[@"channelName"];
        if (!channel || channel.length == 0) channel = LocalizedString(@"unknown_channel");
        
        NSMutableArray *list = self.groupedData[channel];
        if (!list) {
            list = [NSMutableArray array];
            self.groupedData[channel] = list;
            [self.groupedKeys addObject:channel]; // 记录频道的出现顺序
        }
        [list addObject:info];
    }
    
    [self.tableView reloadData];
    [self updateEmptyState]; // [新增] 加载数据后更新空白状态
}

// [新增] 根据分组数量更新空白提示视图
- (void)updateEmptyState {
    if (self.groupedKeys.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] initWithFrame:self.tableView.bounds];
        emptyLabel.text = LocalizedString(@"no_appointments_tips");
        emptyLabel.textColor = [UIColor grayColor];
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.font = [UIFont systemFontOfSize:16.0f];
        emptyLabel.numberOfLines = 0;
        emptyLabel.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = emptyLabel;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    } else {
        self.tableView.backgroundView = nil;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.groupedKeys.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.groupedKeys[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *channel = self.groupedKeys[section];
    NSArray *list = self.groupedData[channel];
    return list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ReminderCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        // [修复] 将样式改为 Subtitle，以支持副标题显示 URL
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    }
    
    NSString *channel = self.groupedKeys[indexPath.section];
    NSArray *list = self.groupedData[channel];
    NSDictionary *info = list[indexPath.row];
    
    NSDate *startTime = info[@"startTime"];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"MM-dd HH:mm"];
    NSString *timeStr = [df stringFromDate:startTime];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@  %@", timeStr, info[@"title"]];
    
    // [新增] 根据记录模式判断是否在副标题显示特定的URL
    NSInteger mode = [PlayerConfigManager watchListRecordMode];
    if (mode == 1 && info[@"url"] && [info[@"url"] length] > 0) {
        cell.detailTextLabel.text = info[@"url"];
    } else {
        cell.detailTextLabel.text = nil;
    }
    
    return cell;
}

// [新增] 点击预约节目列表进行自动匹配并跳转播放
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *channelName = self.groupedKeys[indexPath.section];
    NSArray *list = self.groupedData[channelName];
    NSDictionary *info = list[indexPath.row];
    
    NSString *videoUrl = info[@"url"];
    NSString *tvgName = info[@"tvgName"];
    NSString *catchupSource = info[@"catchupSource"];
    
    // 如果预约信息里没有保存播放链接（纯EPG界面预约时），则去当前激活的直播源里匹配同名频道获取默认链接
    if (!videoUrl || videoUrl.length == 0) {
        NSDictionary *activeSource = [[AppDataManager sharedManager] getActiveSourceInfo];
        NSString *content = activeSource[@"content"];
        if (content && content.length > 0) {
            NSArray *channels = [M3UParser parseM3UString:content];
            for (Channel *ch in channels) {
                if ([ch.name isEqualToString:channelName]) {
                    if (ch.urls.count > 0) {
                        videoUrl = ch.urls.firstObject; // 采用默认的第一个直播源
                        tvgName = ch.tvgName;
                        catchupSource = ch.catchupSource;
                    }
                    break;
                }
            }
        }
    }
    
    if (videoUrl && videoUrl.length > 0) {
        TVPlaybackViewController *playerVC = [[TVPlaybackViewController alloc] init];
        playerVC.videoURLString = videoUrl;
        playerVC.channelTitle = channelName;
        playerVC.tvgName = tvgName;
        playerVC.catchupSource = catchupSource;
        
        playerVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:playerVC animated:YES];
    } else {
        // 没有找到播放链接，提示用户（请确保在语言文件中补充此 key）
        [ToastHelper showToastWithMessage:LocalizedString(@"channel_not_found")];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *channel = self.groupedKeys[indexPath.section];
        NSMutableArray *list = self.groupedData[channel];
        NSDictionary *info = list[indexPath.row];
        
        // 1. 删除底层数据
        [[WatchListDataManager sharedManager] removeAppointment:info];
        
        // 2. 更新分组数据源并执行动画
        [list removeObjectAtIndex:indexPath.row];
        if (list.count == 0) {
            [self.groupedKeys removeObjectAtIndex:indexPath.section];
            [self.groupedData removeObjectForKey:channel];
            [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            
            [self updateEmptyState]; // [新增] 当某个分组都被删光后更新空白状态
        } else {
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return LocalizedString(@"delete");
}

@end