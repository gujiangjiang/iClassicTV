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

@interface WatchListViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITableView *tableView;

// 预留的三个功能数据源
@property (nonatomic, strong) NSMutableArray *favoritesList;
@property (nonatomic, strong) NSMutableArray *recentList;
@property (nonatomic, strong) NSMutableArray *reminderList;

// 记录当前活跃的Tab映射关系
@property (nonatomic, strong) NSArray *activeTabs;

@end

@implementation WatchListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 1. 初始化空数据源 (后续这里可以替换为读取数据库或本地偏好设置缓存)
    self.favoritesList = [NSMutableArray array];
    self.recentList = [NSMutableArray array];
    self.reminderList = [NSMutableArray array];
    
    // 2. 配置顶部分段选择器
    [self setupSegmentedControl];
    
    // 3. 配置主体列表
    [self setupTableView];
    
    // 监听全局语言切换和功能可见性变更的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChange) name:@"LanguageDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabsAndVisibility) name:@"WatchListVisibilityDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTabsAndVisibility) name:NSUserDefaultsDidChangeNotification object:nil];
    
    // 初始化配置
    [self updateTabsAndVisibility];
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
    
    // [优化] 当有超过一个选项时，显示分段选择器；否则隐藏并显示纯文本标题
    if (self.activeTabs.count > 1) {
        for (NSUInteger i = 0; i < items.count; i++) {
            [self.segmentedControl insertSegmentWithTitle:items[i] atIndex:i animated:NO];
        }
        
        [self.segmentedControl sizeToFit];
        self.navigationItem.titleView = nil; // 先置空，确保重新赋值能触发导航栏重绘
        self.navigationItem.titleView = self.segmentedControl;
        self.title = nil; // 清空主标题文字，避免在部分机型上与 titleView 重叠
        
        // 选中逻辑回正
        if (self.segmentedControl.selectedSegmentIndex == UISegmentedControlNoSegment || self.segmentedControl.selectedSegmentIndex >= self.activeTabs.count) {
            self.segmentedControl.selectedSegmentIndex = 0;
        }
    } else {
        // 只有一个或没有选项时，隐藏分段选择器，直接显示标题
        self.navigationItem.titleView = nil;
        if (self.activeTabs.count == 1) {
            self.title = items[0];
        } else {
            // 虽然 AppDelegate 理论上会隐藏整个 Tab，但此处作为兜底显示默认名称
            self.title = LocalizedString(@"watchlist.my_tv");
        }
    }
    
    [self.tableView reloadData];
}

- (void)setupTableView {
    // 使用纯列表风格，最符合平铺展示的数据源
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // 隐藏空数据情况下的多余底部横线
    self.tableView.tableFooterView = [[UIView alloc] init];
    
    [self.view addSubview:self.tableView];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    // 切换不同分类时，直接让表格重载数据即可
    [self.tableView reloadData];
}

- (void)languageDidChange {
    // 同步刷新
    [self updateTabsAndVisibility];
}

#pragma mark - Helper

- (NSInteger)currentSelectedTabType {
    if (self.activeTabs.count == 0) {
        return -1;
    }
    
    NSInteger safeIndex = self.segmentedControl.selectedSegmentIndex;
    // 关键修复：当分段选择器被清空时，其索引是 UISegmentedControlNoSegment，强制归 0
    if (safeIndex == UISegmentedControlNoSegment || safeIndex >= self.activeTabs.count) {
        safeIndex = 0;
    }
    
    return [self.activeTabs[safeIndex] integerValue];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger currentTab = [self currentSelectedTabType];
    
    switch (currentTab) {
        case 0: return self.favoritesList.count;
        case 1: return self.recentList.count;
        case 2: return self.reminderList.count;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"WatchListCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    }
    
    // TODO: 这里预留具体的渲染逻辑，由于暂无真实数据源接入，先置空
    cell.textLabel.text = @"";
    return cell;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end