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
#import "SSLBypassHelper.h"
#import "UIImage+LogoHelper.h"
#import "ToastHelper.h"
#import "PlayerConfigManager.h"
#import "UserAgentManager.h"
#import "UIViewController+ScrollToTop.h"
#import "LanguageManager.h"

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
    
    // 优化：直观地在频道名称后标注支持回放的图标标识
    if (ch.catchupSource.length > 0) {
        cell.textLabel.text = [NSString stringWithFormat:@"%@ [回看]", ch.name];
    } else {
        cell.textLabel.text = ch.name;
    }
    
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    NSString *logoKey = ch.logo.length > 0 ? ch.logo : ch.name;
    UIImage *cachedImage = [self.imageCache objectForKey:logoKey];
    
    if (cachedImage) {
        cell.imageView.image = cachedImage;
    } else {
        UIImage *defaultLogo = [UIImage generateDefaultLogoWithName:ch.name];
        cell.imageView.image = defaultLogo;
        
        if (ch.logo.length > 0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *cleanURLStr = [ch.logo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSURL *url = [NSURL URLWithString:cleanURLStr];
                if (!url) url = [NSURL URLWithString:[cleanURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                
                if (url) {
                    [SSLBypassHelper bypassSSLForHost:url.host];
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                    [request setValue:[[UserAgentManager sharedManager] currentUA] forHTTPHeaderField:@"User-Agent"];
                    [request setTimeoutInterval:15.0];
                    
                    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
                    if (data) {
                        UIImage *downloadedImage = [UIImage imageWithData:data];
                        if (downloadedImage) {
                            UIImage *resizedImage = [downloadedImage resizeAndPadToSize:CGSizeMake(40, 40)];
                            [self.imageCache setObject:resizedImage forKey:logoKey];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (indexPath.row < self.channels.count) {
                                    Channel *currentChannel = self.channels[indexPath.row];
                                    NSString *currentLogoKey = currentChannel.logo.length > 0 ? currentChannel.logo : currentChannel.name;
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
    
    NSString *logoKey = ch.logo.length > 0 ? ch.logo : ch.name;
    UIImage *cachedLogo = [self.imageCache objectForKey:logoKey];
    
    // 优化：传递频道回放源参数
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
    [[NSUserDefaults standardUserDefaults] setInteger:sourceIndex forKey:[self.selectedChannel persistenceKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.tableView reloadData];
    
    NSString *logoKey = self.selectedChannel.logo.length > 0 ? self.selectedChannel.logo : self.selectedChannel.name;
    UIImage *cachedLogo = [self.imageCache objectForKey:logoKey];
    [self playVideoWithURL:self.selectedChannel.urls[sourceIndex] title:self.selectedChannel.name logo:cachedLogo channel:self.selectedChannel];
}

// 优化：扩充传参，将 Channel 对象传入以提取 tvgName 和 catchupSource
- (void)playVideoWithURL:(NSString *)urlString title:(NSString *)title logo:(UIImage *)logo channel:(Channel *)channel {
    NSInteger playerPref = [PlayerConfigManager preferredPlayerType];
    
    if (playerPref == 1) {
        NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
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
        PlayerViewController *playerVC = [[PlayerViewController alloc] init];
        playerVC.videoURLString = urlString;
        playerVC.channelTitle = title;
        playerVC.channelLogo = logo;
        playerVC.tvgName = channel.tvgName;
        // 传递回放模板
        playerVC.catchupSource = channel.catchupSource;
        
        playerVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:playerVC animated:YES completion:nil];
    }
}

@end