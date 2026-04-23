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

@interface ChannelListViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) Channel *selectedChannel;
@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation ChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 55.0;
    self.imageCache = [[NSCache alloc] init];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"ChannelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }
    
    Channel *ch = self.channels[indexPath.row];
    cell.textLabel.text = ch.name;
    
    if (ch.urls.count > 1) {
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"📺 多线路支持 (%lu 条)", (unsigned long)ch.urls.count];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.detailTextLabel.text = @"标准线路";
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
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
                                UITableViewCell *updateCell = [tableView cellForRowAtIndexPath:indexPath];
                                if (updateCell) {
                                    updateCell.imageView.image = resizedImage;
                                    [updateCell setNeedsLayout];
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
        MPMoviePlayerViewController *playerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
        
        UIInterfaceOrientation targetOrientation = [PlayerConfigManager preferredInterfaceOrientation];
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:targetOrientation] forKey:@"orientation"];
        
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