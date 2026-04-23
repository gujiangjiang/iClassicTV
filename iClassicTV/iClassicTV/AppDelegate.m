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
    // 修复：不再使用系统内置样式，防止系统将其强制翻译成 Bookmarks
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Playing" image:nil tag:0];
    
    // 3. 初始化设置页 (原导入页，现已改为设置菜单)
    ImportViewController *importVC = [[ImportViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:importVC];
    // 修复：不再使用系统内置样式，防止系统将其强制翻译成 More
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Setting" image:nil tag:1];
    
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