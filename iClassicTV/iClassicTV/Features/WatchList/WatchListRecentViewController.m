//
//  WatchListRecentViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "WatchListRecentViewController.h"
#import "WatchListDataManager.h"
#import "TVPlaybackViewController.h"
#import "LanguageManager.h"

@interface WatchListRecentViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *dataList;

@end

@implementation WatchListRecentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadData) name:@"WatchListDataDidChangeNotification" object:nil];
    
    [self loadData];
}

- (void)loadData {
    self.dataList = [[WatchListDataManager sharedManager] getRecentPlays];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"RecentCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    }
    
    if (indexPath.row < self.dataList.count) {
        NSDictionary *info = self.dataList[indexPath.row];
        cell.textLabel.text = info[@"name"];
        cell.detailTextLabel.text = info[@"url"];
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSMutableArray *temp = [self.dataList mutableCopy];
        [temp removeObjectAtIndex:indexPath.row];
        self.dataList = temp;
        
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [[WatchListDataManager sharedManager] removeRecentPlayAtIndex:indexPath.row];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return LocalizedString(@"delete");
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row < self.dataList.count) {
        NSDictionary *info = self.dataList[indexPath.row];
        
        TVPlaybackViewController *playerVC = [[TVPlaybackViewController alloc] init];
        playerVC.videoURLString = info[@"url"];
        playerVC.channelTitle = info[@"name"];
        playerVC.tvgName = info[@"tvgName"];
        playerVC.catchupSource = info[@"catchupSource"];
        
        playerVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:playerVC animated:YES];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end