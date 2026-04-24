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
// 新增：引入数据管理器，用于保存外部导入的源
#import "AppDataManager.h"
#import "NSString+EncodingHelper.h" // 引入字符串编码处理辅助模块
// 新增：引入滚动处理通用模块
#import "UIViewController+ScrollToTop.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"频道列表" image:[UIImage dynamicPlayTabBarIcon] tag:0];
    
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"设置" image:[UIImage dynamicSettingsTabBarIcon] tag:1];
    
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[nav1, nav2];
    
    // 新增：将代理设置为自己，从而可以拦截 Tab 的重复点击事件
    self.tabBarController.delegate = self;
    
    self.window.rootViewController = self.tabBarController;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    return YES;
}

#pragma mark - UITabBarControllerDelegate

// 新增：处理点击 TabBar 的逻辑，实现双击回到最上方功能
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    // 如果用户点击的依然是当前已经处于选中状态的 Tab
    if (tabBarController.selectedViewController == viewController) {
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)viewController;
            // 找到该导航控制器下最顶层的视图，并调用通用模块使其滚动到顶部
            [nav.topViewController scrollToTopAnimated:YES];
        }
        return YES;
    }
    return YES;
}

// 新增：拦截并处理系统外部传入的文件 (Open In...)
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if (url.isFileURL) {
        NSString *extension = [[url pathExtension] lowercaseString];
        if ([extension isEqualToString:@"m3u"] || [extension isEqualToString:@"m3u8"]) {
            // 优化：外部传入的是本地文件，直接使用本地文件路径读取方式并保留编码回退支持
            NSString *content = [NSString stringWithContentsOfFileWithFallback:[url path]];
            
            if (content && content.length > 0) {
                // 以源文件名作为基础进行命名备注
                NSString *fileName = [[url lastPathComponent] stringByDeletingPathExtension];
                NSString *sourceName = [NSString stringWithFormat:@"外部导入: %@", fileName];
                
                // 将接收到的内容写入系统直播源
                [[AppDataManager sharedManager] addSourceWithName:sourceName content:content url:@""];
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"导入成功" message:[NSString stringWithFormat:@"已自动关联并添加新直播源：\n%@", sourceName] delegate:nil cancelButtonTitle:@"太棒了" otherButtonTitles:nil];
                [alert show];
                
                // 导入完毕后删除 Inbox 缓存文件，节约存储空间
                [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
                
                return YES;
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"导入失败" message:@"读取文件内容失败或文件为空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
            }
        }
    }
    return NO;
}

@end