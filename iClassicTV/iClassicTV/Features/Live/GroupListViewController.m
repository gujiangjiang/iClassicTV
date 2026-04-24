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
#import "NSString+EncodingHelper.h" // 引入字符串编码处理辅助模块
// 新增：引入滚动处理通用模块
#import "UIViewController+ScrollToTop.h"

@implementation GroupListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"频道列表"; // 优化：默认标题改为频道列表
    self.navigationItem.title = @"加载中..."; // 优化：单独设置顶部导航栏的初始标题
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    
    // 新增：调用通用模块，为当前导航栏标题栏注册双击回到最上方的功能
    [self enableNavigationBarDoubleTapToScrollTop];
    
    // 监听数据更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadDataFromUserDefaults) name:@"M3UDataUpdated" object:nil];
    [self loadDataFromUserDefaults];
}

- (void)loadDataFromUserDefaults {
    // 优化：调用独立模块处理旧版数据无缝迁移，保持控制器代码简洁
    [[AppDataManager sharedManager] migrateLegacyDataIfNeeded];
    
    // 优化：直接通过 AppDataManager 获取当前激活源的数据
    NSDictionary *activeSource = [[AppDataManager sharedManager] getActiveSourceInfo];
    NSString *activeM3U = activeSource[@"content"];
    NSString *activeName = activeSource[@"name"];
    NSString *activeUrl = activeSource[@"url"];
    
    // 逻辑：只有当存在直播源列表，且当前激活的源是“网络源”时，才显示右上角的同步刷新按钮
    NSArray *allSources = [[AppDataManager sharedManager] getAllSources];
    if (allSources.count > 0 && activeUrl.length > 0) {
        UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshActiveSourceFromServer)];
        self.navigationItem.rightBarButtonItem = refreshBtn;
    } else {
        self.navigationItem.rightBarButtonItem = nil; // 无源或本地源则隐藏按钮
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
            
            // 优化：动态显示源的名称及空白状态提示
            if (self.groupNames.count == 0) {
                self.navigationItem.title = @"暂无可用直播源"; // 优化：修改无源时的标题更符合语境
                
                // 构建好看的空白提示引导视图
                UIView *emptyView = [[UIView alloc] initWithFrame:self.tableView.bounds];
                emptyView.backgroundColor = [UIColor clearColor];
                
                UILabel *tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, self.tableView.bounds.size.width - 40, self.tableView.bounds.size.height - 120)];
                tipsLabel.text = @"📺\n\n暂无可用直播源\n\n请点击底部【设置】->【我的直播源】进行添加";
                tipsLabel.textColor = [UIColor grayColor];
                tipsLabel.textAlignment = NSTextAlignmentCenter;
                tipsLabel.numberOfLines = 0;
                tipsLabel.font = [UIFont systemFontOfSize:16];
                tipsLabel.backgroundColor = [UIColor clearColor];
                
                [emptyView addSubview:tipsLabel];
                self.tableView.backgroundView = emptyView;
                self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            } else {
                self.navigationItem.title = activeName;
                self.tableView.backgroundView = nil;
                self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
            }
        });
    });
}

// 核心优化：执行真正的网络同步刷新
- (void)refreshActiveSourceFromServer {
    NSDictionary *activeSource = [[AppDataManager sharedManager] getActiveSourceInfo];
    NSString *urlStr = activeSource[@"url"];
    if (urlStr.length == 0) return;
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if (!url) return;
    
    // 显示 iOS 6 风格的 HUD 提示
    UIAlertView *hud = [[UIAlertView alloc] initWithTitle:@"正在同步..." message:@"正在从网络更新直播源内容\n\n" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [hud show];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 优化：使用独立模块下载文件，自动处理 UTF-8 和 GBK 编码回退
        NSString *m3uData = [NSString stringWithContentsOfURLWithFallback:url];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismissWithClickedButtonIndex:0 animated:YES];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            if (m3uData && m3uData.length > 0) {
                // 查找当前源在列表中的索引并更新
                NSMutableArray *sources = [[AppDataManager sharedManager] getAllSources];
                NSInteger activeIndex = NSNotFound;
                for (int i = 0; i < sources.count; i++) {
                    if ([sources[i][@"id"] isEqualToString:activeSource[@"id"]]) {
                        activeIndex = i;
                        break;
                    }
                }
                
                if (activeIndex != NSNotFound) {
                    [[AppDataManager sharedManager] updateSourceContentAtIndex:activeIndex withContent:m3uData];
                    // 此处 update 方法内部会发出 M3UDataUpdated 通知，从而自动触发界面的 loadDataFromUserDefaults
                }
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"同步失败" message:@"无法连接到源地址，请检查网络或链接是否有效" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
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