//
//  ChannelListViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "ChannelListViewController.h"
#import "Channel.h"
#import <MediaPlayer/MediaPlayer.h>
#import "TVPlaybackViewController.h" // [修改] 引用新的播放器控制器
#import "NetworkManager.h"           // [优化] 引入统一下载管理器，移除原先独立的 SSLBypassHelper 和 UserAgentManager 引用
#import "UIImage+LogoHelper.h"
#import "ToastHelper.h"
#import "PlayerConfigManager.h"
#import "UIViewController+ScrollToTop.h"
#import "LanguageManager.h"
#import "NSString+EncodingHelper.h" // [优化] 引入编码助手以使用 toSafeURL
#import "TVSearchManager.h"         // [新增] 引入独立的搜索模块

@interface CustomNativePlayerViewController : MPMoviePlayerViewController
@end

@implementation CustomNativePlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localizeSystemDoneButton) name:MPMoviePlayerNowPlayingMovieDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localizeSystemDoneButton) name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self localizeSystemDoneButton];
}

- (void)localizeSystemDoneButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self traverseAndUpdateDoneButtonInView:self.view];
    });
}

- (void)traverseAndUpdateDoneButtonInView:(UIView *)view {
    if ([view isKindOfClass:[UINavigationBar class]]) {
        UINavigationBar *navBar = (UINavigationBar *)view;
        for (UINavigationItem *item in navBar.items) {
            // [优化] 识别系统原生按钮标识符 "Done" 或 "Back"，并统一替换为语言包中的 "back" 字段文案
            // 彻底移除硬编码的中文字符串匹配，确保代码符合多语言规范
            NSString *leftTitle = item.leftBarButtonItem.title;
            if (leftTitle && ([leftTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame ||
                              [leftTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) {
                item.leftBarButtonItem.title = LocalizedString(@"back");
            }
            
            NSString *rightTitle = item.rightBarButtonItem.title;
            if (rightTitle && ([rightTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame ||
                               [rightTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) {
                item.rightBarButtonItem.title = LocalizedString(@"back");
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            NSString *currentTitle = [btn currentTitle];
            NSString *normalTitle = [btn titleForState:UIControlStateNormal];
            
            // 检查按钮文案是否为系统预设的退出标识符
            BOOL isDoneOrBack = NO;
            if (currentTitle && ([currentTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame ||
                                 [currentTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) {
                isDoneOrBack = YES;
            } else if (normalTitle && ([normalTitle caseInsensitiveCompare:@"Done"] == NSOrderedSame ||
                                       [normalTitle caseInsensitiveCompare:@"Back"] == NSOrderedSame)) {
                isDoneOrBack = YES;
            }
            
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

// [优化] 接入独立搜索模块的代理协议
@interface ChannelListViewController () <UIActionSheetDelegate, TVSearchManagerDelegate>
@property (nonatomic, strong) Channel *selectedChannel;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) TVSearchManager *searchManager; // [新增]
@end

@implementation ChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 55.0;
    self.imageCache = [[NSCache alloc] init];
    [self enableNavigationBarDoubleTapToScrollTop];
    
    // [新增] 接入独立搜索模块
    self.searchManager = [[TVSearchManager alloc] initWithContentsController:self];
    self.searchManager.delegate = self;
    self.searchManager.sourceChannels = self.channels;
    self.tableView.tableHeaderView = self.searchManager.searchBar;
    
    // [新增] 默认隐藏搜索框，下拉显示
    self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.searchManager.searchBar.bounds));
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"ChannelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
    }
    
    Channel *ch = self.channels[indexPath.row];
    
    cell.textLabel.text = ch.name;
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    // [优化] 使用统一的方法获取 logoKey
    NSString *logoKey = [ch logoIdentifier];
    UIImage *cachedImage = [self.imageCache objectForKey:logoKey];
    
    if (cachedImage) {
        cell.imageView.image = cachedImage;
    } else {
        UIImage *defaultLogo = [UIImage generateDefaultLogoWithName:ch.name];
        cell.imageView.image = defaultLogo;
        
        if (ch.logo.length > 0) {
            // [优化] 使用弱引用避免 block 造成循环引用和潜在的内存泄露
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *cleanURLStr = [ch.logo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                // [优化] 调用统一定义的 toSafeURL 方法解析 URL
                NSURL *url = [cleanURLStr toSafeURL];
                
                if (url) {
                    // [优化] 提取冗余的网络请求逻辑，直接复用 NetworkManager 的同步下载方法
                    NSData *data = [[NetworkManager sharedManager] downloadDataSyncFromURL:url];
                    if (data) {
                        UIImage *downloadedImage = [UIImage imageWithData:data];
                        if (downloadedImage) {
                            UIImage *resizedImage = [downloadedImage resizeAndPadToSize:CGSizeMake(40, 40)];
                            [weakSelf.imageCache setObject:resizedImage forKey:logoKey];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (weakSelf && indexPath.row < weakSelf.channels.count) {
                                    Channel *currentChannel = weakSelf.channels[indexPath.row];
                                    NSString *currentLogoKey = [currentChannel logoIdentifier];
                                    if ([currentLogoKey isEqualToString:logoKey]) {
                                        UITableViewCell *updateCell = [tableView cellForRowAtIndexPath:indexPath];
                                        if (updateCell) {
                                            updateCell.imageView.image = resizedImage;
                                            [updateCell setNeedsLayout];
                                        }
                                    }
                                }
                            });
                        }
                    }
                }
            });
        } else {
            [self.imageCache setObject:defaultLogo forKey:logoKey];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    Channel *ch = self.channels[indexPath.row];
    NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[ch persistenceKey]];
    
    if (savedIndex >= ch.urls.count) {
        [ToastHelper showToastWithMessage:[NSString stringWithFormat:LocalizedString(@"line_invalid_fallback"), (long)savedIndex + 1]];
        savedIndex = 0;
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[ch persistenceKey]];
    }
    
    // [优化] 使用统一的方法获取 logoKey
    NSString *logoKey = [ch logoIdentifier];
    UIImage *cachedLogo = [self.imageCache objectForKey:logoKey];
    
    [self playVideoWithURL:ch.urls[savedIndex] title:ch.name logo:cachedLogo channel:ch];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    self.selectedChannel = self.channels[indexPath.row];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"switch_playback_line") delegate:self cancelButtonTitle:LocalizedString(@"cancel") destructiveButtonTitle:nil otherButtonTitles:nil];
    NSInteger currentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[self.selectedChannel persistenceKey]];
    
    for (int i = 0; i < self.selectedChannel.urls.count; i++) {
        NSString *title = (i == currentIndex) ? [NSString stringWithFormat:LocalizedString(@"line_current_format"), i+1] : [NSString stringWithFormat:LocalizedString(@"line_format"), i+1];
        [sheet addButtonWithTitle:title];
    }
    [sheet showInView:self.view];
}

#pragma mark - TVSearchManagerDelegate (对接搜索回调)

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

#pragma mark - Action Sheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    NSInteger sourceIndex = buttonIndex - 1;
    
    // [优化] 增加越界保护，防止极端情况下的崩溃
    if (sourceIndex < 0 || sourceIndex >= self.selectedChannel.urls.count) return;
    
    [[NSUserDefaults standardUserDefaults] setInteger:sourceIndex forKey:[self.selectedChannel persistenceKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // [优化] 动态判断需刷新的列表视图
    if (self.searchManager.searchController.isActive) {
        [self.searchManager reloadSearchResults];
    } else {
        [self.tableView reloadData];
    }
#pragma clang diagnostic pop
    
    // [优化] 使用统一的方法获取 logoKey
    NSString *logoKey = [self.selectedChannel logoIdentifier];
    UIImage *cachedLogo = [self.imageCache objectForKey:logoKey];
    [self playVideoWithURL:self.selectedChannel.urls[sourceIndex] title:self.selectedChannel.name logo:cachedLogo channel:self.selectedChannel];
}

- (void)playVideoWithURL:(NSString *)urlString title:(NSString *)title logo:(UIImage *)logo channel:(Channel *)channel {
    NSInteger playerPref = [PlayerConfigManager preferredPlayerType];
    
    if (playerPref == 1) {
        // [优化] 直接使用统一封装的 toSafeURL 方法进行 URL 转换
        NSURL *url = [urlString toSafeURL];
        
        CustomNativePlayerViewController *playerVC = [[CustomNativePlayerViewController alloc] initWithContentURL:url];
        
        NSInteger orientationPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        if (orientationPref == 1) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
        } else if (orientationPref == 2) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationPortrait] forKey:@"orientation"];
        }
        
        [self presentMoviePlayerViewControllerAnimated:playerVC];
        [playerVC.moviePlayer play];
    } else {
        // [修改] 实例化全新的播放模块
        TVPlaybackViewController *playerVC = [[TVPlaybackViewController alloc] init];
        playerVC.videoURLString = urlString;
        playerVC.channelTitle = title;
        playerVC.channelLogo = logo;
        playerVC.tvgName = channel.tvgName;
        playerVC.catchupSource = channel.catchupSource;
        
        // [优化] 弃用模态弹出，改为推入独立页面的方式展示
        playerVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:playerVC animated:YES];
    }
}

@end