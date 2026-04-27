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

@interface AppDelegate () <UITabBarControllerDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UINavigationController *navWatchList; // 保留实例以备动态添加
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    
    // ==========================================
    // [新增] 兼容 iOS 8+ 的本地通知权限申请 (处理旧版 Xcode 编译报错)
#ifdef __IPHONE_8_0
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound) categories:nil];
        [application registerUserNotificationSettings:settings];
    }
#endif
    // ==========================================
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:LocalizedString(@"channel_list") image:[UIImage dynamicPlayTabBarIcon] tag:0];
    
    WatchListViewController *watchListVC = [[WatchListViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:watchListVC];
    // 初始化时先设置图标，标题将由 updateWatchListTabVisibility 统一计算
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"" image:[UIImage dynamicWatchListTabBarIcon] tag:1];
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWatchListTabVisibility) name:NSUserDefaultsDidChangeNotification object:nil];
    
    // 首次加载立即计算标题并决定是否展现“我的电视”Tab
    [self updateWatchListTabVisibility];
    
    // 根据设置决定打开软件默认显示的页面
    if ([PlayerConfigManager defaultStartupPage] == 1) {
        if ([self.tabBarController.viewControllers containsObject:self.navWatchList]) {
            self.tabBarController.selectedViewController = self.navWatchList;
        }
    }
    
    // [新增] 处理冷启动时用户点击预约通知拉起APP的情况
    UILocalNotification *localNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (localNotif) {
        if ([localNotif.userInfo[@"isEPGReminder"] boolValue]) {
            // 稍微延迟跳转，等待根视图初始化完全
            [self performSelector:@selector(jumpToAppointmentsTab) withObject:nil afterDelay:0.5];
        }
    }
    
    return YES;
}

// [新增] 接收到本地通知时的代理方法
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if ([userInfo[@"isEPGReminder"] boolValue]) {
        // 如果 App 处于前台运行状态，则不走系统的顶部推送，直接由 App 内部弹窗提醒
        if (application.applicationState == UIApplicationStateActive) {
            NSString *channel = userInfo[@"channelName"];
            NSString *title = userInfo[@"title"];
            NSDate *startTime = userInfo[@"startTime"];
            
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"MM-dd HH:mm"];
            NSString *timeStr = [df stringFromDate:startTime];
            
            NSString *msg = [NSString stringWithFormat:LocalizedString(@"reminder_alert_msg"), channel, timeStr, title];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"reminder_alert_title") message:msg delegate:self cancelButtonTitle:LocalizedString(@"reminder_ignore") otherButtonTitles:LocalizedString(@"reminder_go"), nil];
            alert.tag = 1001; // 用来区分是否为提醒弹窗
            [alert show];
        } else {
            // 如果 App 是在后台运行，点击通知进来，则直接跳转预约列表界面
            [self jumpToAppointmentsTab];
        }
    }
}

// [新增] 处理内部应用弹窗点击“立即前往”跳转预约界面的逻辑
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1001 && buttonIndex == 1) {
        [self jumpToAppointmentsTab];
    }
}

// [新增] 跳转至“我的电视”预约页的辅助方法
- (void)jumpToAppointmentsTab {
    [self updateWatchListTabVisibility];
    if ([self.tabBarController.viewControllers containsObject:self.navWatchList]) {
        self.tabBarController.selectedViewController = self.navWatchList;
        // 如果 WatchListViewController 中有多个子 Tab（如最近、收藏、预约），可以使用通知触发切换
        [[NSNotificationCenter defaultCenter] postNotificationName:@"JumpToAppointmentsTabNotification" object:nil];
    }
}

// 辅助方法：计算当前“我的电视”Tab 应该显示的标题文字
- (NSString *)currentWatchListTargetTitle {
    BOOL showFavorites = [PlayerConfigManager enableFavoritesTab];
    BOOL showRecent = [PlayerConfigManager enableRecentPlayTab];
    BOOL showReminder = ([EPGManager sharedManager].epgSources.count > 0);
    
    int activeCount = (showFavorites ? 1 : 0) + (showRecent ? 1 : 0) + (showReminder ? 1 : 0);
    if (activeCount == 1) {
        if (showFavorites) return LocalizedString(@"watchlist.favorites");
        if (showRecent) return LocalizedString(@"watchlist.recent_play");
        if (showReminder) return LocalizedString(@"watchlist.appointments");
    }
    return LocalizedString(@"watchlist.my_tv");
}

- (void)updateWatchListTabVisibility {
    BOOL showFavorites = [PlayerConfigManager enableFavoritesTab];
    BOOL showRecent = [PlayerConfigManager enableRecentPlayTab];
    BOOL showReminder = ([EPGManager sharedManager].epgSources.count > 0);
    
    BOOL shouldShowWatchList = showFavorites || showRecent || showReminder;
    
    NSMutableArray *vcs = [self.tabBarController.viewControllers mutableCopy];
    if (!vcs) return;
    
    BOOL isCurrentlyShowing = [vcs containsObject:self.navWatchList];
    
    if (shouldShowWatchList) {
        // 在显示之前，先更新一次标题，确保文字是正确的（尤其是只有一个功能时）
        self.navWatchList.tabBarItem.title = [self currentWatchListTargetTitle];
        
        if (!isCurrentlyShowing) {
            if (vcs.count >= 1) {
                [vcs insertObject:self.navWatchList atIndex:1];
            } else {
                [vcs addObject:self.navWatchList];
            }
            self.tabBarController.viewControllers = vcs;
        }
    } else if (isCurrentlyShowing) {
        [vcs removeObject:self.navWatchList];
        self.tabBarController.viewControllers = vcs;
    }
}

- (void)languageDidChange {
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
    
    // 语言切换后重新刷新“我的电视”底栏标题
    self.navWatchList.tabBarItem.title = [self currentWatchListTargetTitle];
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