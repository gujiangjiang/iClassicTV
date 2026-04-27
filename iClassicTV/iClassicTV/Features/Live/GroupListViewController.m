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
#import "ToastHelper.h"

// [新增] 引入搜索模块及播放器依赖，以便通过分组列表直接搜索并触发播放
#import "TVSearchManager.h"
#import <MediaPlayer/MediaPlayer.h>
#import "TVPlaybackViewController.h"
#import "PlayerConfigManager.h"

// [新增] 内部复用原生播放器，与频道列表逻辑保持一致
@interface GroupNativePlayerViewController : MPMoviePlayerViewController
@end

@implementation GroupNativePlayerViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localizeSystemDoneButton) name:MPMoviePlayerNowPlayingMovieDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localizeSystemDoneButton) name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self localizeSystemDoneButton]; }

- (void)localizeSystemDoneButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self traverseAndUpdateDoneButtonInView:self.view];
    });
}
- (void)traverseAndUpdateDoneButtonInView:(UIView *)view {
    if ([view isKindOfClass:[UINavigationBar class]]) {
        UINavigationBar *navBar = (UINavigationBar *)view;
        for (UINavigationItem *item in navBar.items) {
            NSString *leftTitle = item.leftBarButtonItem.title;
            if (leftTitle && ([leftTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame || [leftTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) { item.leftBarButtonItem.title = LocalizedString(@"back"); }
            NSString *rightTitle = item.rightBarButtonItem.title;
            if (rightTitle && ([rightTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame || [rightTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) { item.rightBarButtonItem.title = LocalizedString(@"back"); }
        }
    }
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            NSString *currentTitle = [btn currentTitle];
            NSString *normalTitle = [btn titleForState:UIControlStateNormal];
            BOOL isDoneOrBack = NO;
            if (currentTitle && ([currentTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame || [currentTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) isDoneOrBack = YES;
            else if (normalTitle && ([normalTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame || [normalTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) isDoneOrBack = YES;
            if (isDoneOrBack) {
                [btn setTitle:LocalizedString(@"back") forState:UIControlStateNormal];
                [btn setTitle:LocalizedString(@"back") forState:UIControlStateHighlighted];
            }
        }
        [self traverseAndUpdateDoneButtonInView:subview];
    }
}
- (BOOL)shouldAutorotate { return YES; }
- (NSUInteger)supportedInterfaceOrientations {
    NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
    if (pref == 1) return UIInterfaceOrientationMaskLandscape;
    else if (pref == 2) return UIInterfaceOrientationMaskPortrait;
    return UIInterfaceOrientationMaskAllButUpsideDown;
}
@end

@interface GroupListViewController () <TVSearchManagerDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) TVSearchManager *searchManager; // [新增]
@property (nonatomic, strong) Channel *selectedChannel; // [新增] 供搜索层切换线路用
@end

@implementation GroupListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    
    [self enableNavigationBarDoubleTapToScrollTop];
    
    // 监听数据与多语言的更新
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLanguageChange) name:@"LanguageDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadDataFromUserDefaults) name:@"M3UDataUpdated" object:nil];
    
    // [新增] 初始化独立搜索模块
    self.searchManager = [[TVSearchManager alloc] initWithContentsController:self];
    self.searchManager.delegate = self;
    self.tableView.tableHeaderView = self.searchManager.searchBar;
    
    // [新增] 默认隐藏搜索框
    self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchManager.searchBar.bounds));
    
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
            
            // [新增] 数据解析完成后，将全量数据灌入搜索池
            weakSelf.searchManager.sourceChannels = parsedChannels;
            
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

#pragma mark - TVSearchManagerDelegate (从分组列表搜到频道直接触发)

- (void)searchManager:(id)manager didSelectChannel:(Channel *)channel {
    NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[channel persistenceKey]];
    
    if (savedIndex >= channel.urls.count) {
        [ToastHelper showToastWithMessage:[NSString stringWithFormat:LocalizedString(@"line_invalid_fallback"), (long)savedIndex + 1]];
        savedIndex = 0;
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[channel persistenceKey]];
    }
    
    UIImage *cachedLogo = [self.searchManager cachedImageForChannel:channel];
    [self playVideoWithURL:channel.urls[savedIndex] title:channel.name logo:cachedLogo channel:channel];
}

- (void)searchManager:(id)manager accessoryButtonTappedForChannel:(Channel *)channel {
    self.selectedChannel = channel;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"switch_playback_line") delegate:self cancelButtonTitle:LocalizedString(@"cancel") destructiveButtonTitle:nil otherButtonTitles:nil];
    NSInteger currentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[self.selectedChannel persistenceKey]];
    
    for (int i = 0; i < self.selectedChannel.urls.count; i++) {
        NSString *title = (i == currentIndex) ? [NSString stringWithFormat:LocalizedString(@"line_current_format"), i+1] : [NSString stringWithFormat:LocalizedString(@"line_format"), i+1];
        [sheet addButtonWithTitle:title];
    }
    [sheet showInView:self.view];
}

#pragma mark - Action Sheet Delegate (响应搜索模式下属的线路切换)

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    NSInteger sourceIndex = buttonIndex - 1;
    
    if (sourceIndex < 0 || sourceIndex >= self.selectedChannel.urls.count) return;
    
    [[NSUserDefaults standardUserDefaults] setInteger:sourceIndex forKey:[self.selectedChannel persistenceKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (self.searchManager.searchController.isActive) {
        [self.searchManager reloadSearchResults];
    }
#pragma clang diagnostic pop
    
    UIImage *cachedLogo = [self.searchManager cachedImageForChannel:self.selectedChannel];
    [self playVideoWithURL:self.selectedChannel.urls[sourceIndex] title:self.selectedChannel.name logo:cachedLogo channel:self.selectedChannel];
}

#pragma mark - Video Playback (复用频道列表的播放下发引擎)

- (void)playVideoWithURL:(NSString *)urlString title:(NSString *)title logo:(UIImage *)logo channel:(Channel *)channel {
    NSInteger playerPref = [PlayerConfigManager preferredPlayerType];
    
    if (playerPref == 1) {
        NSURL *url = [urlString toSafeURL];
        
        GroupNativePlayerViewController *playerVC = [[GroupNativePlayerViewController alloc] initWithContentURL:url];
        
        NSInteger orientationPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        if (orientationPref == 1) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
        } else if (orientationPref == 2) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationPortrait] forKey:@"orientation"];
        }
        
        [self presentMoviePlayerViewControllerAnimated:playerVC];
        [playerVC.moviePlayer play];
    } else {
        TVPlaybackViewController *playerVC = [[TVPlaybackViewController alloc] init];
        playerVC.videoURLString = urlString;
        playerVC.channelTitle = title;
        playerVC.channelLogo = logo;
        playerVC.tvgName = channel.tvgName;
        playerVC.catchupSource = channel.catchupSource;
        
        playerVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:playerVC animated:YES];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end