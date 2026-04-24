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
            self.allChannels = parsedChannels;
            self.groupedChannels = dict;
            self.groupNames = orderedGroupNames;
            
            [self.tableView reloadData];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            if (self.groupNames.count == 0) {
                self.navigationItem.title = LocalizedString(@"no_sources_title");
                
                UIView *emptyView = [[UIView alloc] initWithFrame:self.tableView.bounds];
                emptyView.backgroundColor = [UIColor clearColor];
                
                UILabel *tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, self.tableView.bounds.size.width - 40, self.tableView.bounds.size.height - 120)];
                tipsLabel.text = LocalizedString(@"no_sources_tips");
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

- (void)refreshActiveSourceFromServer {
    NSDictionary *activeSource = [[AppDataManager sharedManager] getActiveSourceInfo];
    NSString *urlStr = activeSource[@"url"];
    if (urlStr.length == 0) return;
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if (!url) return;
    
    UIAlertView *hud = [[UIAlertView alloc] initWithTitle:LocalizedString(@"syncing") message:LocalizedString(@"syncing_msg") delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [hud show];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *m3uData = [[NetworkManager sharedManager] downloadStringSyncFromURL:url];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismissWithClickedButtonIndex:0 animated:YES];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            if (m3uData && m3uData.length > 0) {
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
                }
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"sync_failed") message:LocalizedString(@"sync_failed_msg") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
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