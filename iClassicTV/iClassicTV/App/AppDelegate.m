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

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 1. 初始化应用主窗口
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // 2. 初始化频道列表页 (带入原生分组样式)
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    // 优化：修改文字为 "频道列表"，并调用独立绘图模块
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"频道列表" image:[UIImage dynamicPlayTabBarIcon] tag:0];
    
    // 3. 初始化设置页
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    // 修复：将默认初始化的标题由 "Setting" 改为 "设置"，并调用独立绘图模块
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

// 优化：移除了冗余的 generatePlayIcon 和 generateSettingsIcon 绘制代码，已提取至 UIImage+DynamicIcon.m

@end