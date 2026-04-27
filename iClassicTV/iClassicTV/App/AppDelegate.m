//
//  AppDelegate.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AppDelegate.h"
#import "GroupListViewController.h"
#import "SettingsViewController.h"
#import "WatchListViewController.h"
#import "UIImage+DynamicIcon.h"
#import <AVFoundation/AVFoundation.h>
#import "AppDataManager.h"
#import "NSString+EncodingHelper.h"
#import "UIViewController+ScrollToTop.h"
#import "LanguageManager.h"
#import "PlayerConfigManager.h"
#import "EPGManager.h"

@interface AppDelegate () <UITabBarControllerDelegate>
@property (nonatomic, strong) UINavigationController *navWatchList; // 保留实例以备动态添加
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:LocalizedString(@"channel_list") image:[UIImage dynamicPlayTabBarIcon] tag:0];
    
    WatchListViewController *watchListVC = [[WatchListViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:watchListVC];
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:LocalizedString(@"watchlist.my_tv") image:[UIImage dynamicWatchListTabBarIcon] tag:1];
    self.navWatchList = nav2;
    
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav3 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav3.tabBarItem = [[UITabBarItem alloc] initWithTitle:LocalizedString(@"settings") image:[UIImage dynamicSettingsTabBarIcon] tag:2];
    
    self.tabBarController = [[UITabBarController alloc] init];
    // 初始化时先注册必须展现的两个控制器
    self.tabBarController.viewControllers = @[nav1, nav3];
    self.tabBarController.delegate = self;
    
    self.window.rootViewController = self.tabBarController;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChange) name:@"LanguageDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWatchListTabVisibility) name:@"WatchListVisibilityDidChangeNotification" object:nil];
    // 监听全局保存操作以感知可能发生的 EPG 数据或配置变动
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWatchListTabVisibility) name:NSUserDefaultsDidChangeNotification object:nil];
    
    // 触发判断是否展现“我的电视”Tab
    [self updateWatchListTabVisibility];
    
    return YES;
}

- (void)updateWatchListTabVisibility {
    BOOL showFavorites = [PlayerConfigManager enableFavoritesTab];
    BOOL showRecent = [PlayerConfigManager enableRecentPlayTab];
    BOOL showReminder = ([EPGManager sharedManager].epgSources.count > 0);
    
    // 三个条件满足一个就显示主 Tab
    BOOL shouldShowWatchList = showFavorites || showRecent || showReminder;
    
    NSMutableArray *vcs = [self.tabBarController.viewControllers mutableCopy];
    if (!vcs) return;
    
    BOOL isCurrentlyShowing = [vcs containsObject:self.navWatchList];
    
    if (shouldShowWatchList && !isCurrentlyShowing) {
        if (vcs.count >= 1) {
            [vcs insertObject:self.navWatchList atIndex:1];
        } else {
            [vcs addObject:self.navWatchList];
        }
        self.tabBarController.viewControllers = vcs;
    } else if (!shouldShowWatchList && isCurrentlyShowing) {
        [vcs removeObject:self.navWatchList];
        self.tabBarController.viewControllers = vcs;
    }
}

- (void)languageDidChange {
    // 动态遍历查找对应的 ViewController 进行多语言更新，防止因隐藏了Tab导致获取崩溃越界
    for (UIViewController *vc in self.tabBarController.viewControllers) {
        if ([vc isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)vc;
            if ([nav.topViewController isKindOfClass:[GroupListViewController class]]) {
                nav.tabBarItem.title = LocalizedString(@"channel_list");
            } else if ([nav.topViewController isKindOfClass:[SettingsViewController class]]) {
                nav.tabBarItem.title = LocalizedString(@"settings");
            }
        }
    }
    
    // 直接更新已持有的实例引用
    self.navWatchList.tabBarItem.title = LocalizedString(@"watchlist.my_tv");
}

#pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    if (tabBarController.selectedViewController == viewController) {
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)viewController;
            [nav.topViewController scrollToTopAnimated:YES];
        }
        return YES;
    }
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if (url.isFileURL) {
        NSString *extension = [[url pathExtension] lowercaseString];
        if ([extension isEqualToString:@"m3u"] || [extension isEqualToString:@"m3u8"]) {
            NSString *content = [NSString stringWithContentsOfFileWithFallback:[url path]];
            
            if (content && content.length > 0) {
                NSString *fileName = [[url lastPathComponent] stringByDeletingPathExtension];
                NSString *sourceName = [NSString stringWithFormat:LocalizedString(@"external_import_format"), fileName];
                
                [[AppDataManager sharedManager] addSourceWithName:sourceName content:content url:@""];
                
                NSString *successMsg = [NSString stringWithFormat:LocalizedString(@"import_success_msg"), sourceName];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"import_success") message:successMsg delegate:nil cancelButtonTitle:LocalizedString(@"great") otherButtonTitles:nil];
                [alert show];
                
                [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
                
                return YES;
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"import_failed") message:LocalizedString(@"file_read_error") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
                [alert show];
            }
        }
    }
    return NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end