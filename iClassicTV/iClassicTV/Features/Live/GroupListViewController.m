//
//  GroupListViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "GroupListViewController.h"
#import "ChannelListViewController.h"
#import "M3UParser.h"
#import "Channel.h"
// 引入数据管理模块，实现数据迁移逻辑的解耦
#import "AppDataManager.h"

@implementation GroupListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"频道列表"; // 优化：默认标题改为频道列表
    self.navigationItem.title = @"加载中..."; // 优化：单独设置顶部导航栏的初始标题
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    
    // iOS 6 风格：添加下拉刷新提示
    UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadDataFromUserDefaults)];
    self.navigationItem.rightBarButtonItem = refreshBtn;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadDataFromUserDefaults) name:@"M3UDataUpdated" object:nil];
    [self loadDataFromUserDefaults];
}

- (void)loadDataFromUserDefaults {
    // 优化：调用独立模块处理旧版数据无缝迁移，保持控制器代码简洁
    [[AppDataManager sharedManager] migrateLegacyDataIfNeeded];
    
    // 优化：直接通过 AppDataManager 获取当前激活源的数据，移除了冗余的循环遍历寻找逻辑
    NSDictionary *activeSource = [[AppDataManager sharedManager] getActiveSourceInfo];
    NSString *activeM3U = activeSource[@"content"];
    NSString *activeName = activeSource[@"name"];
    
    // 显示网络活动指示器（状态栏小圈圈）
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *parsedChannels = [M3UParser parseM3UString:activeM3U]; // activeM3U 可能为空，解析器会返回空数组
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        NSMutableArray *orderedGroupNames = [NSMutableArray array];
        
        for (Channel *ch in parsedChannels) {
            if (!dict[ch.group]) {
                dict[ch.group] = [NSMutableArray array];
                [orderedGroupNames addObject:ch.group];
            }
            [dict[ch.group] addObject:ch];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allChannels = parsedChannels;
            self.groupedChannels = dict;
            self.groupNames = orderedGroupNames;
            
            [self.tableView reloadData];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            // 优化：动态显示源的名称及空白状态提示
            if (self.groupNames.count == 0) {
                self.navigationItem.title = @"暂无可用直播源"; // 优化：修改无源时的标题更符合语境
                
                // 新增：构建好看的空白提示引导视图
                UIView *emptyView = [[UIView alloc] initWithFrame:self.tableView.bounds];
                emptyView.backgroundColor = [UIColor clearColor];
                
                // 使用 Label 构建多行居中的提示文字，Y轴减去120让视觉中心稍微偏上一点更美观
                UILabel *tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, self.tableView.bounds.size.width - 40, self.tableView.bounds.size.height - 120)];
                tipsLabel.text = @"📺\n\n暂无可用直播源\n\n请点击底部【设置】->【我的直播源】进行添加";
                tipsLabel.textColor = [UIColor grayColor];
                tipsLabel.textAlignment = NSTextAlignmentCenter;
                tipsLabel.numberOfLines = 0;
                tipsLabel.font = [UIFont systemFontOfSize:16];
                tipsLabel.backgroundColor = [UIColor clearColor];
                
                [emptyView addSubview:tipsLabel];
                self.tableView.backgroundView = emptyView;
                self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone; // 无数据时隐藏多余的分割线，保持界面干净
            } else {
                self.navigationItem.title = activeName;
                self.tableView.backgroundView = nil; // 有数据时移除空白提示视图
                self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine; // 恢复原生的分组分割线样式
            }
        });
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.groupNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"GroupCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *groupName = self.groupNames[indexPath.row];
    NSArray *channelsInGroup = self.groupedChannels[groupName];
    
    cell.textLabel.text = groupName;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)channelsInGroup.count];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *groupName = self.groupNames[indexPath.row];
    NSArray *channelsInGroup = self.groupedChannels[groupName];
    
    ChannelListViewController *channelVC = [[ChannelListViewController alloc] initWithStyle:UITableViewStylePlain];
    channelVC.channels = channelsInGroup;
    channelVC.title = groupName;
    
    [self.navigationController pushViewController:channelVC animated:YES];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end