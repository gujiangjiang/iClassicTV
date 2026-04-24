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
#import "UIImage+DynamicIcon.h"
#import <AVFoundation/AVFoundation.h>
#import "AppDataManager.h"
#import "NSString+EncodingHelper.h"
#import "UIViewController+ScrollToTop.h"
#import "LanguageManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:LocalizedString(@"channel_list") image:[UIImage dynamicPlayTabBarIcon] tag:0];
    
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:LocalizedString(@"settings") image:[UIImage dynamicSettingsTabBarIcon] tag:1];
    
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[nav1, nav2];
    self.tabBarController.delegate = self;
    
    self.window.rootViewController = self.tabBarController;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChange) name:@"LanguageDidChangeNotification" object:nil];
    
    return YES;
}

- (void)languageDidChange {
    if (self.tabBarController.viewControllers.count >= 2) {
        UIViewController *nav1 = self.tabBarController.viewControllers[0];
        nav1.tabBarItem.title = LocalizedString(@"channel_list");
        
        UIViewController *nav2 = self.tabBarController.viewControllers[1];
        nav2.tabBarItem.title = LocalizedString(@"settings");
    }
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
                // 优化：使用了合并后的 file_read_error 错误提示键
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