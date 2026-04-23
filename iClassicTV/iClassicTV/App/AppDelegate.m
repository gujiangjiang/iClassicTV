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
// 引入动态图标绘制模块
#import "UIImage+DynamicIcon.h"
// 新增：引入音视频基础框架，用于配置后台播放权限
#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 新增：配置全局音频会话 (Audio Session)
    // 设置类别为 AVAudioSessionCategoryPlayback 可以实现：
    // 1. 允许在静音模式下播放声音
    // 2. 配合 Info.plist 权限，允许应用在退到后台或锁屏时继续播放音频
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    
    // 1. 初始化应用主窗口
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // 2. 初始化频道列表页 (带入原生分组样式)
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"频道列表" image:[UIImage dynamicPlayTabBarIcon] tag:0];
    
    // 3. 初始化设置页
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"设置" image:[UIImage dynamicSettingsTabBarIcon] tag:1];
    
    // 4. 组装底部 TabBar
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[nav1, nav2];
    
    // 5. 将 TabBar 设置为窗口的根视图
    self.window.rootViewController = self.tabBarController;
    self.window.backgroundColor = [UIColor whiteColor];
    
    // 6. 激活并显示窗口
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end