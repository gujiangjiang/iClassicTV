#import "AppDelegate.h"
#import "GroupListViewController.h"
#import "ImportViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 1. 初始化应用主窗口
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // 2. 初始化频道列表页 (带入原生分组样式)
    GroupListViewController *groupVC = [[GroupListViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:groupVC];
    // 使用系统的"书签"图标作为频道列表
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:0];
    nav1.tabBarItem.title = @"频道"; // 强制把名字改回"频道"
    
    // 3. 初始化导入设置页
    ImportViewController *importVC = [[ImportViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:importVC];
    // 使用系统的"下载"图标作为导入
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemDownloads tag:1];
    nav2.tabBarItem.title = @"导入"; // 强制把名字改回"导入"
    
    // 4. 组装底部 TabBar
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = @[nav1, nav2];
    
    // 5. 将 TabBar 设置为窗口的根视图 (★★★★★ 解决白屏的关键所在)
    self.window.rootViewController = self.tabBarController;
    self.window.backgroundColor = [UIColor whiteColor]; // 给底层铺个白底
    
    // 6. 激活并显示窗口
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end