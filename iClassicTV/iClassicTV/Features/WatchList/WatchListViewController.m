//
//  WatchListViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "WatchListViewController.h"
#import "LanguageManager.h"

@interface WatchListViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITableView *tableView;

// 预留的三个功能数据源
@property (nonatomic, strong) NSMutableArray *favoritesList;
@property (nonatomic, strong) NSMutableArray *recentList;
@property (nonatomic, strong) NSMutableArray *reminderList;

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
    
    // 监听全局语言切换通知，实时更新 UI
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChange) name:@"LanguageDidChangeNotification" object:nil];
}

- (void)setupSegmentedControl {
    NSArray *items = @[LocalizedString(@"watchlist.favorites"),
                       LocalizedString(@"watchlist.recent_play"),
                       LocalizedString(@"watchlist.appointments")];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:items];
    self.segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    self.segmentedControl.selectedSegmentIndex = 0; // 默认选中“收藏”
    
    // 设置文字属性，使其在 iOS 6 上显示更加紧凑和美观
    NSDictionary *attributes = @{UITextAttributeFont: [UIFont boldSystemFontOfSize:12.0f]};
    [self.segmentedControl setTitleTextAttributes:attributes forState:UIControlStateNormal];
    
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 将分段选择器作为 NavigationBar 的 TitleView
    self.navigationItem.titleView = self.segmentedControl;
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
    // 同步刷新分段选择器的多语言文字
    [self.segmentedControl setTitle:LocalizedString(@"watchlist.favorites") forSegmentAtIndex:0];
    [self.segmentedControl setTitle:LocalizedString(@"watchlist.recent_play") forSegmentAtIndex:1];
    [self.segmentedControl setTitle:LocalizedString(@"watchlist.appointments") forSegmentAtIndex:2];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (self.segmentedControl.selectedSegmentIndex) {
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