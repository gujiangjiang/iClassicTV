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
#import "PlayerViewController.h"
// 引入独立模块
#import "SSLBypassHelper.h"
#import "UIImage+LogoHelper.h"
#import "ToastHelper.h"
#import "PlayerConfigManager.h"
// 新增：引入滚动处理通用模块
#import "UIViewController+ScrollToTop.h"

// --- 修复：新增自定义的原生播放器子类，用于接管并强制控制原生播放器的屏幕旋转逻辑 ---
@interface CustomNativePlayerViewController : MPMoviePlayerViewController
@end

@implementation CustomNativePlayerViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    // 读取用户设置中的全屏方向偏好 (0: 跟随系统, 1: 横屏, 2: 竖屏)
    NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
    if (pref == 1) {
        // 强制横屏
        return UIInterfaceOrientationMaskLandscape;
    } else if (pref == 2) {
        // 强制竖屏
        return UIInterfaceOrientationMaskPortrait;
    }
    // 跟随系统 (支持除倒立外的所有方向)
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
// ---------------------------------------------------------------------

@interface ChannelListViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) Channel *selectedChannel;
@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation ChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 55.0;
    self.imageCache = [[NSCache alloc] init];
    
    // 新增：调用通用模块，为当前导航栏标题栏注册双击回到最上方的功能
    [self enableNavigationBarDoubleTapToScrollTop];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"ChannelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        // 优化：统一使用 Default 样式，不再显示多余的副标题区域，使频道名称垂直居中更美观
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
    }
    
    Channel *ch = self.channels[indexPath.row];
    cell.textLabel.text = ch.name;
    
    // 优化：统一视图逻辑，不论单线还是多线，列表均不再显示具体线路数量，且全部统一提供箭头以供点击进入线路选择
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    NSString *logoKey = ch.logo.length > 0 ? ch.logo : ch.name;
    UIImage *cachedImage = [self.imageCache objectForKey:logoKey];
    
    if (cachedImage) {
        cell.imageView.image = cachedImage;
    } else {
        // 调用独立模块生成图片
        UIImage *defaultLogo = [UIImage generateDefaultLogoWithName:ch.name];
        cell.imageView.image = defaultLogo;
        
        if (ch.logo.length > 0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *cleanURLStr = [ch.logo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSURL *url = [NSURL URLWithString:cleanURLStr];
                if (!url) url = [NSURL URLWithString:[cleanURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                
                if (url) {
                    // 调用独立模块绕过 SSL
                    [SSLBypassHelper bypassSSLForHost:url.host];
                    
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 Version/6.0 Mobile/10A5376e Safari/8536.25" forHTTPHeaderField:@"User-Agent"];
                    [request setTimeoutInterval:15.0];
                    
                    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
                    if (data) {
                        UIImage *downloadedImage = [UIImage imageWithData:data];
                        if (downloadedImage) {
                            // 调用独立模块缩放图片
                            UIImage *resizedImage = [downloadedImage resizeAndPadToSize:CGSizeMake(40, 40)];
                            [self.imageCache setObject:resizedImage forKey:logoKey];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                // 优化：安全检查，防止快速滚动时 Cell 复用导致的图片错乱
                                if (indexPath.row < self.channels.count) {
                                    Channel *currentChannel = self.channels[indexPath.row];
                                    NSString *currentLogoKey = currentChannel.logo.length > 0 ? currentChannel.logo : currentChannel.name;
                                    
                                    // 只有当前 indexPath 对应的数据依然是发起请求时的数据，才更新 UI
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
        // 调用独立模块显示 Toast
        [ToastHelper showToastWithMessage:[NSString stringWithFormat:@"线路 %ld 已失效，回到默认线路", (long)savedIndex + 1]];
        savedIndex = 0;
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[ch persistenceKey]];
    }
    
    // 优化：从缓存中获取对应的 Logo 图片传递给播放器
    NSString *logoKey = ch.logo.length > 0 ? ch.logo : ch.name;
    UIImage *cachedLogo = [self.imageCache objectForKey:logoKey];
    [self playVideoWithURL:ch.urls[savedIndex] title:ch.name logo:cachedLogo];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    self.selectedChannel = self.channels[indexPath.row];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"切换播放线路" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:nil];
    NSInteger currentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[self.selectedChannel persistenceKey]];
    
    for (int i = 0; i < self.selectedChannel.urls.count; i++) {
        NSString *title = (i == currentIndex) ? [NSString stringWithFormat:@"线路 %d (当前选择)", i+1] : [NSString stringWithFormat:@"线路 %d", i+1];
        [sheet addButtonWithTitle:title];
    }
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    NSInteger sourceIndex = buttonIndex - 1;
    [[NSUserDefaults standardUserDefaults] setInteger:sourceIndex forKey:[self.selectedChannel persistenceKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.tableView reloadData];
    
    // 优化：从缓存中获取对应的 Logo 图片传递给播放器
    NSString *logoKey = self.selectedChannel.logo.length > 0 ? self.selectedChannel.logo : self.selectedChannel.name;
    UIImage *cachedLogo = [self.imageCache objectForKey:logoKey];
    [self playVideoWithURL:self.selectedChannel.urls[sourceIndex] title:self.selectedChannel.name logo:cachedLogo];
}

// 优化：方法签名增加 logo 参数
- (void)playVideoWithURL:(NSString *)urlString title:(NSString *)title logo:(UIImage *)logo {
    // 调用配置模块读取偏好
    NSInteger playerPref = [PlayerConfigManager preferredPlayerType];
    
    if (playerPref == 1) {
        NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        // 修复：使用自定义的原生播放器子类，以支持方向控制
        CustomNativePlayerViewController *playerVC = [[CustomNativePlayerViewController alloc] initWithContentURL:url];
        
        // 修复：根据偏好设置预先旋转设备，解决默认总是横屏的 Bug
        NSInteger orientationPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        if (orientationPref == 1) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
        } else if (orientationPref == 2) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationPortrait] forKey:@"orientation"];
        }
        // 如果是 0 (跟随系统)，则不主动修改 UIDevice 的方向，让其自然跟随系统状态
        
        [self presentMoviePlayerViewControllerAnimated:playerVC];
        [playerVC.moviePlayer play];
    } else {
        PlayerViewController *playerVC = [[PlayerViewController alloc] init];
        playerVC.videoURLString = urlString;
        playerVC.channelTitle = title;
        // 传入 Logo
        playerVC.channelLogo = logo;
        playerVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:playerVC animated:YES completion:nil];
    }
}

@end