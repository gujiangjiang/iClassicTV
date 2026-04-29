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
    
    // 处理冷启动时用户点击预约通知拉起APP的情况
    UILocalNotification *localNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (localNotif) {
        // [修复] 必须先拷贝 userInfo，防止取消通知后对象被释放
        NSDictionary *userInfo = [localNotif.userInfo copy];
        
        if ([userInfo[@"isEPGReminder"] boolValue]) {
            // 冷启动点击通知时，清零角标并取消通知，以将其从通知中心彻底移除
            application.applicationIconBadgeNumber = 1;
            application.applicationIconBadgeNumber = 0;
            [application cancelLocalNotification:localNotif];
            
            // 检查预约是否已过期
            NSDate *endTime = userInfo[@"endTime"];
            NSDate *startTime = userInfo[@"startTime"];
            // 如果没有传入 endTime，作为 fallback，默认节目开播后 2 小时视为过期
            NSDate *checkTime = endTime ? endTime : (startTime ? [startTime dateByAddingTimeInterval:2 * 3600] : nil);
            
            if (checkTime && [[NSDate date] compare:checkTime] == NSOrderedDescending) {
                // [修复] 传参改为安全的 userInfo 字典
                [self performSelector:@selector(showExpiredAlertForUserInfo:) withObject:userInfo afterDelay:0.5];
            } else {
                // 未过期，稍微延迟跳转，等待根视图初始化完全
                [self performSelector:@selector(jumpToAppointmentsTab) withObject:nil afterDelay:0.5];
            }
        }
    }
    
    return YES;
}

// 接收到本地通知时的代理方法
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    // [修复] 严重内存溢出 Bug：在取消通知前必须先将 userInfo 提取并持有拷贝！
    // 否则 cancelLocalNotification 可能会导致系统提前释放 notification 指针，后续读取闪退
    NSDictionary *userInfo = [notification.userInfo copy];
    
    // 收到或点击通知进入前台时，清零角标并取消该通知，以将其从系统通知中心移除
    application.applicationIconBadgeNumber = 1;
    application.applicationIconBadgeNumber = 0;
    [application cancelLocalNotification:notification];
    
    if ([userInfo[@"isEPGReminder"] boolValue]) {
        // 检查预约是否已过期
        NSDate *endTime = userInfo[@"endTime"];
        NSDate *startTime = userInfo[@"startTime"];
        NSDate *checkTime = endTime ? endTime : (startTime ? [startTime dateByAddingTimeInterval:2 * 3600] : nil);
        
        if (checkTime && [[NSDate date] compare:checkTime] == NSOrderedDescending) {
            // [修复] 增加延迟调用，防止在后台被唤醒转场的过程中同步弹出 Alert 导致被系统视图层级吞掉而无法显示
            [self performSelector:@selector(showExpiredAlertForUserInfo:) withObject:userInfo afterDelay:0.5];
            return;
        }
        
        // 如果 App 处于前台运行状态，则不走系统的顶部推送，直接由 App 内部弹窗提醒
        if (application.applicationState == UIApplicationStateActive) {
            NSString *channel = userInfo[@"channelName"] ?: @"";
            NSString *title = userInfo[@"title"] ?: @"";
            
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"MM-dd HH:mm"];
            NSString *timeStr = startTime ? [df stringFromDate:startTime] : @"";
            
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

// 处理内部应用弹窗点击“立即前往”跳转预约界面的逻辑
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1001 && buttonIndex == 1) {
        [self jumpToAppointmentsTab];
    }
}

// [修复] 将参数类型从 UILocalNotification 变更为 NSDictionary，保证数据的绝对安全
- (void)showExpiredAlertForUserInfo:(NSDictionary *)userInfo {
    if (!userInfo) return;
    
    NSString *channel = userInfo[@"channelName"] ?: @"";
    NSString *title = userInfo[@"title"] ?: @"";
    
    // 取出 userInfo 中的回放标志位（兼容不同命名习惯）
    BOOL supportsPlayback = [userInfo[@"supportsPlayback"] boolValue] || [userInfo[@"supportPlayback"] boolValue] || [userInfo[@"catchup"] boolValue];
    
    NSString *msg = @"";
    if (supportsPlayback) {
        msg = [NSString stringWithFormat:LocalizedString(@"reminder_expired_catchup_msg"), channel, title];
    } else {
        msg = [NSString stringWithFormat:LocalizedString(@"reminder_expired_msg"), channel, title];
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:msg delegate:nil cancelButtonTitle:LocalizedString(@"reminder_expired_ok") otherButtonTitles:nil];
    [alert show];
}

// 跳转至“我的电视”预约页的辅助方法
- (void)jumpToAppointmentsTab {
    [self updateWatchListTabVisibility];
    if ([self.tabBarController.viewControllers containsObject:self.navWatchList]) {
        self.tabBarController.selectedViewController = self.navWatchList;
        
        // 强制触发视图控制器的 view 加载，防止其尚未初始化（viewDidLoad未执行）导致漏接后续通知
        [self.navWatchList.topViewController view];
        
        // 将发送跳转通知的操作放到主队列异步执行，确保视图已完全准备好接收并在正确的生命周期响应
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"JumpToAppointmentsTabNotification" object:nil];
        });
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