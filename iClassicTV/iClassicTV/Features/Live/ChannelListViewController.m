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
            if ([item.leftBarButtonItem.title isEqualToString:@"Done"]) {
                item.leftBarButtonItem.title = LocalizedString(@"back");
            }
            if ([item.rightBarButtonItem.title isEqualToString:@"Done"]) {
                item.rightBarButtonItem.title = LocalizedString(@"back");
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            if ([[btn currentTitle] isEqualToString:@"Done"] || [[btn titleForState:UIControlStateNormal] isEqualToString:@"Done"]) {
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

@interface ChannelListViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) Channel *selectedChannel;
@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation ChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 55.0;
    self.imageCache = [[NSCache alloc] init];
    [self enableNavigationBarDoubleTapToScrollTop];
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
                    // [优化] 提取冗余的网络请求逻辑，直接复用 NetworkManager 的同步下载方法，内部已封装好 SSL、UA 和 超时处理
                    NSData *data = [[NetworkManager sharedManager] downloadDataSyncFromURL:url];
                    if (data) {
                        UIImage *downloadedImage = [UIImage imageWithData:data];
                        if (downloadedImage) {
                            UIImage *resizedImage = [downloadedImage resizeAndPadToSize:CGSizeMake(40, 40)];
                            [weakSelf.imageCache setObject:resizedImage forKey:logoKey];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                // [优化] 安全检查 self 是否还存在
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

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    NSInteger sourceIndex = buttonIndex - 1;
    
    // [优化] 增加越界保护，防止极端情况下的崩溃
    if (sourceIndex < 0 || sourceIndex >= self.selectedChannel.urls.count) return;
    
    [[NSUserDefaults standardUserDefaults] setInteger:sourceIndex forKey:[self.selectedChannel persistenceKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.tableView reloadData];
    
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
        
        // [优化] 弃用模态弹出，改为推入独立页面的方式展示，从底层规避 iOS6 状态栏布局错乱问题
        playerVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:playerVC animated:YES];
    }
}

@end