#import "AppDelegate.h"
#import "GroupListViewController.h"
#import "SettingsViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 1. 初始化应用主窗口
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // 2. 初始化频道列表页 (带入原生分组样式)
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    // 优化：修改文字为 "频道列表"
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"频道列表" image:[self generatePlayIcon] tag:0];
    
    // 3. 初始化设置页
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Setting" image:[self generateSettingsIcon] tag:1];
    
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

#pragma mark - 动态绘制图标 (无需导入 PNG 图片即可显示原生图标)

// 绘制“播放”图标 (经典播放三角形)
- (UIImage *)generatePlayIcon {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(10, 6)];
    [path addLineToPoint:CGPointMake(24, 15)];
    [path addLineToPoint:CGPointMake(10, 24)];
    [path closePath];
    
    [[UIColor blackColor] setFill];
    [path fill];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 绘制“设置”图标 (经典调节控制条样式)
- (UIImage *)generateSettingsIcon {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    [[UIColor blackColor] setFill];
    
    // 第一行滑动条
    [[UIBezierPath bezierPathWithRect:CGRectMake(4, 8, 22, 2)] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10, 5, 8, 8)] fill];
    
    // 第二行滑动条
    [[UIBezierPath bezierPathWithRect:CGRectMake(4, 15, 22, 2)] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18, 12, 8, 8)] fill];
    
    // 第三行滑动条
    [[UIBezierPath bezierPathWithRect:CGRectMake(4, 22, 22, 2)] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(6, 19, 8, 8)] fill];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end