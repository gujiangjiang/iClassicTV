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
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    // ================= 新增：数据迁移逻辑 (旧版单源无损迁移至新版多源架构) =================
    NSString *legacyM3U = [defs objectForKey:@"ios6_iptv_m3u"];
    if (legacyM3U) {
        NSString *sourceId = [[NSUUID UUID] UUIDString];
        NSDictionary *source = @{@"id": sourceId, @"name": @"默认直播源 (旧版)", @"content": legacyM3U, @"url": @""};
        [defs setObject:@[source] forKey:@"ios6_iptv_sources"];
        [defs setObject:sourceId forKey:@"ios6_iptv_active_source_id"];
        [defs removeObjectForKey:@"ios6_iptv_m3u"]; // 销毁老旧存储，避免重复执行
        [defs synchronize];
    }
    // ==============================================================================
    
    // 读取多源数据
    NSArray *sources = [defs objectForKey:@"ios6_iptv_sources"];
    NSString *activeId = [defs objectForKey:@"ios6_iptv_active_source_id"];
    
    NSString *activeM3U = nil;
    NSString *activeName = @"频道列表";
    
    // 找出当前选中的源并提取数据
    for (NSDictionary *dict in sources) {
        if ([dict[@"id"] isEqualToString:activeId]) {
            activeM3U = dict[@"content"];
            activeName = dict[@"name"];
            break;
        }
    }
    
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
            
            // 优化：动态显示源的名称（只修改 navigationItem.title，这样不会影响底部的 TabBar）
            if (self.groupNames.count == 0) {
                self.navigationItem.title = @"请先添加直播源";
            } else {
                self.navigationItem.title = activeName;
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