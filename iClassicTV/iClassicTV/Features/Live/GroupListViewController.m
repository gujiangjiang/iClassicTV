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
#import "AppDataManager.h"
#import "NSString+EncodingHelper.h"
#import "NetworkManager.h"
#import "UIViewController+ScrollToTop.h"
#import "LanguageManager.h"
#import "ToastHelper.h" // 新增：引入 ToastHelper 用于刷新状态提示

@implementation GroupListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    
    [self enableNavigationBarDoubleTapToScrollTop];
    
    // 监听数据与多语言的更新
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLanguageChange) name:@"LanguageDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadDataFromUserDefaults) name:@"M3UDataUpdated" object:nil];
    
    // 手动触发一次初始化界面文本
    [self handleLanguageChange];
}

// 新增：专门处理语言改变时的页面 UI 刷新
- (void)handleLanguageChange {
    self.title = LocalizedString(@"channel_list");
    
    // 强制设置推送至下一级页面（频道页）时的左上角返回按钮文本，确保其支持多语言
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"back") style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.navigationItem.backBarButtonItem = backItem;
    
    // 重新加载数据，以便刷新空白提示（tips）等多语言文本
    [self loadDataFromUserDefaults];
}

- (void)loadDataFromUserDefaults {
    [[AppDataManager sharedManager] migrateLegacyDataIfNeeded];
    
    NSDictionary *activeSource = [[AppDataManager sharedManager] getActiveSourceInfo];
    NSString *activeM3U = activeSource[@"content"];
    NSString *activeName = activeSource[@"name"];
    NSString *activeUrl = activeSource[@"url"];
    
    NSArray *allSources = [[AppDataManager sharedManager] getAllSources];
    if (allSources.count > 0 && activeUrl.length > 0) {
        UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshActiveSourceFromServer)];
        self.navigationItem.rightBarButtonItem = refreshBtn;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
    
    self.navigationItem.title = LocalizedString(@"loading");
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    // [优化] 增加 weakSelf 防止内存泄漏
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *parsedChannels = [M3UParser parseM3UString:activeM3U];
        
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
            if (!weakSelf) return; // 保护
            
            weakSelf.allChannels = parsedChannels;
            weakSelf.groupedChannels = dict;
            weakSelf.groupNames = orderedGroupNames;
            
            [weakSelf.tableView reloadData];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            if (weakSelf.groupNames.count == 0) {
                weakSelf.navigationItem.title = LocalizedString(@"no_sources_title");
                
                UIView *emptyView = [[UIView alloc] initWithFrame:weakSelf.tableView.bounds];
                emptyView.backgroundColor = [UIColor clearColor];
                
                UILabel *tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, weakSelf.tableView.bounds.size.width - 40, weakSelf.tableView.bounds.size.height - 120)];
                tipsLabel.text = LocalizedString(@"no_sources_tips");
                tipsLabel.textColor = [UIColor grayColor];
                tipsLabel.textAlignment = NSTextAlignmentCenter;
                tipsLabel.numberOfLines = 0;
                tipsLabel.font = [UIFont systemFontOfSize:16];
                tipsLabel.backgroundColor = [UIColor clearColor];
                
                [emptyView addSubview:tipsLabel];
                weakSelf.tableView.backgroundView = emptyView;
                weakSelf.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            } else {
                weakSelf.navigationItem.title = activeName;
                weakSelf.tableView.backgroundView = nil;
                weakSelf.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
            }
        });
    });
}

// [优化] 接入 AppDataManager 中统一提取好的同步功能模块
- (void)refreshActiveSourceFromServer {
    NSDictionary *activeSource = [[AppDataManager sharedManager] getActiveSourceInfo];
    NSString *sourceId = activeSource[@"id"];
    
    if (!sourceId || [activeSource[@"url"] length] == 0) return;
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [[AppDataManager sharedManager] refreshSourceFromNetworkWithId:sourceId completion:^(BOOL success, NSString *message) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        // 成功后 AppDataManager 内部会自动抛出 "M3UDataUpdated" 通知触发 loadDataFromUserDefaults 刷新页面
    }];
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