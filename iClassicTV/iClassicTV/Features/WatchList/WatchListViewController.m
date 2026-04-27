//
//  WatchListViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "WatchListViewController.h"
#import "LanguageManager.h"
#import "PlayerConfigManager.h"
#import "EPGManager.h"

// 引入解耦后的三个独立子控制器
#import "WatchListFavoritesViewController.h"
#import "WatchListRecentViewController.h"
#import "WatchListReminderViewController.h"

@interface WatchListViewController ()

@property (nonatomic, strong) UISegmentedControl *segmentedControl;

// 独立维护三个子页面
@property (nonatomic, strong) WatchListFavoritesViewController *favVC;
@property (nonatomic, strong) WatchListRecentViewController *recentVC;
@property (nonatomic, strong) WatchListReminderViewController *reminderVC;

// 记录当前活跃的Tab映射关系
@property (nonatomic, strong) NSArray *activeTabs;

@end

@implementation WatchListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // [修复] 适配 iOS 7+ 视图布局，强制视图从导航栏下方开始，避免内部的列表被顶部 Tab 遮挡
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    // 初始化并挂载子控制器，将列表逻辑完全剥离出去
    [self setupChildViewControllers];
    
    // 配置顶部分段选择器
    [self setupSegmentedControl];
    
    // 监听全局语言切换和功能可见性变更的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChange) name:@"LanguageDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabsAndVisibility) name:@"WatchListVisibilityDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabsAndVisibility) name:NSUserDefaultsDidChangeNotification object:nil];
    
    // [新增] 监听来自 AppDelegate 的跳转到预约 Tab 的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jumpToAppointmentsTabNotification:) name:@"JumpToAppointmentsTabNotification" object:nil];
    
    // 初始化配置和加载页面展示
    [self updateTabsAndVisibility];
}

// 将列表页面作为子层级挂载
- (void)setupChildViewControllers {
    self.favVC = [[WatchListFavoritesViewController alloc] init];
    self.recentVC = [[WatchListRecentViewController alloc] init];
    self.reminderVC = [[WatchListReminderViewController alloc] init];
    
    [self addChildViewController:self.favVC];
    [self addChildViewController:self.recentVC];
    [self addChildViewController:self.reminderVC];
    
    self.favVC.view.frame = self.view.bounds;
    self.recentVC.view.frame = self.view.bounds;
    self.reminderVC.view.frame = self.view.bounds;
    
    self.favVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.recentVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.reminderVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.view addSubview:self.favVC.view];
    [self.view addSubview:self.recentVC.view];
    [self.view addSubview:self.reminderVC.view];
}

- (void)setupSegmentedControl {
    self.segmentedControl = [[UISegmentedControl alloc] init];
    self.segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    
    // 设置文字属性，使其在 iOS 6 上显示更加紧凑和美观
    NSDictionary *attributes = @{UITextAttributeFont: [UIFont boldSystemFontOfSize:12.0f]};
    [self.segmentedControl setTitleTextAttributes:attributes forState:UIControlStateNormal];
    
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)updateTabsAndVisibility {
    NSMutableArray *items = [NSMutableArray array];
    NSMutableArray *tabs = [NSMutableArray array];
    
    // 根据设置动态生成存在的Tab项，数字代表数据源类型（0:收藏，1:最近播放，2:预约）
    if ([PlayerConfigManager enableFavoritesTab]) {
        [items addObject:LocalizedString(@"watchlist.favorites")];
        [tabs addObject:@(0)];
    }
    
    if ([PlayerConfigManager enableRecentPlayTab]) {
        [items addObject:LocalizedString(@"watchlist.recent_play")];
        [tabs addObject:@(1)];
    }
    
    // 仅在 EPG 数据不为空的情况下才显示预约板块
    if ([EPGManager sharedManager].epgSources.count > 0) {
        [items addObject:LocalizedString(@"watchlist.appointments")];
        [tabs addObject:@(2)];
    }
    
    self.activeTabs = tabs;
    
    // 先清空所有分段，防止旧数据残留
    [self.segmentedControl removeAllSegments];
    
    if (self.activeTabs.count > 1) {
        for (NSUInteger i = 0; i < items.count; i++) {
            [self.segmentedControl insertSegmentWithTitle:items[i] atIndex:i animated:NO];
        }
        
        [self.segmentedControl sizeToFit];
        self.navigationItem.titleView = nil; // 先置空，确保重新赋值能触发导航栏重绘
        self.navigationItem.titleView = self.segmentedControl;
        
        // 只清空顶部导航栏的标题，不使用 self.title = nil
        self.navigationItem.title = nil;
        // 显式恢复底部 Tab 的标题，防止丢失
        self.navigationController.tabBarItem.title = LocalizedString(@"watchlist.my_tv");
        
        // 选中逻辑回正
        if (self.segmentedControl.selectedSegmentIndex == UISegmentedControlNoSegment || self.segmentedControl.selectedSegmentIndex >= self.activeTabs.count) {
            self.segmentedControl.selectedSegmentIndex = 0;
        }
    } else {
        // 只有一个或没有选项时，隐藏分段选择器，直接显示标题
        self.navigationItem.titleView = nil;
        if (self.activeTabs.count == 1) {
            self.navigationItem.title = items[0];
            self.navigationController.tabBarItem.title = items[0];
        } else {
            // 虽然 AppDelegate 理论上会隐藏整个 Tab，但此处作为兜底显示默认名称
            self.navigationItem.title = LocalizedString(@"watchlist.my_tv");
            self.navigationController.tabBarItem.title = LocalizedString(@"watchlist.my_tv");
        }
    }
    
    // 触发页面切换展示逻辑
    [self showCurrentSelectedVC];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    // 切换不同分类时，让对应的子页面层级浮现
    [self showCurrentSelectedVC];
}

- (void)languageDidChange {
    // 同步刷新
    [self updateTabsAndVisibility];
}

// [新增] 接收到跳转通知后的处理逻辑
- (void)jumpToAppointmentsTabNotification:(NSNotification *)notif {
    // 寻找代表“预约”的索引 (标记为 2)
    NSUInteger targetIndex = [self.activeTabs indexOfObject:@(2)];
    if (targetIndex != NSNotFound) {
        self.segmentedControl.selectedSegmentIndex = targetIndex;
        [self showCurrentSelectedVC];
    }
}

#pragma mark - Helper

- (NSInteger)currentSelectedTabType {
    if (self.activeTabs.count == 0) {
        return -1;
    }
    
    NSInteger safeIndex = self.segmentedControl.selectedSegmentIndex;
    // 当分段选择器被清空时，其索引是 UISegmentedControlNoSegment，强制归 0
    if (safeIndex == UISegmentedControlNoSegment || safeIndex >= self.activeTabs.count) {
        safeIndex = 0;
    }
    
    return [self.activeTabs[safeIndex] integerValue];
}

// 控制视图显示与隐藏
- (void)showCurrentSelectedVC {
    NSInteger currentTab = [self currentSelectedTabType];
    
    self.favVC.view.hidden = YES;
    self.recentVC.view.hidden = YES;
    self.reminderVC.view.hidden = YES;
    
    if (currentTab == 0) {
        self.favVC.view.hidden = NO;
        [self.view bringSubviewToFront:self.favVC.view];
    } else if (currentTab == 1) {
        self.recentVC.view.hidden = NO;
        [self.view bringSubviewToFront:self.recentVC.view];
    } else if (currentTab == 2) {
        self.reminderVC.view.hidden = NO;
        [self.view bringSubviewToFront:self.reminderVC.view];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end