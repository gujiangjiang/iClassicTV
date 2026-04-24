//
//  SettingsViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "SettingsViewController.h"
#import "SourceManagerViewController.h"
#import "AboutViewController.h"
#import "UAManagerViewController.h" // 引入 UA 管理模块
#import "AppDataManager.h" // 引入数据管理模块
#import "UIViewController+ScrollToTop.h" // 引入滚动处理通用模块
#import "DataManagementViewController.h" // 新增：引入数据管理与备份模块

@interface SettingsViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *sections;
@end

@implementation SettingsViewController

- (instancetype)init { self = [super initWithStyle:UITableViewStyleGrouped]; return self; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    
    // 调用通用模块，为当前导航栏标题栏注册双击回到最上方的功能
    [self enableNavigationBarDoubleTapToScrollTop];
    
    // 优化：重构设置列表，将危险的清空操作移入专属的数据管理页面
    self.sections = @[
                      @{@"title": @"直播源设置", @"rows": @[@"我的直播源 (管理与添加)"]},
                      @{@"title": @"软件设置", @"rows": @[@"默认全屏逻辑", @"默认播放器", @"User-Agent 设置"]},
                      @{@"title": @"数据与安全", @"rows": @[@"数据管理与备份"]}, // 新增：数据管理入口
                      @{@"title": @"关于", @"rows": @[@"关于 iClassicTV"]}
                      ];
}

// 优化：每次出现时刷新列表，确保显示的偏好设置状态是最新的
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.sections[section][@"rows"] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.sections[section][@"title"]; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    
    cell.textLabel.text = self.sections[indexPath.section][@"rows"][indexPath.row];
    cell.detailTextLabel.text = @"";
    
    // 统一设置基础样式
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.textLabel.textColor = [UIColor blackColor];
    
    // 显示软件设置的当前状态
    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
            cell.detailTextLabel.text = (pref == 1) ? @"横屏" : ((pref == 2) ? @"竖屏" : @"跟随系统");
        } else if (indexPath.row == 1) {
            NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerTypePref"];
            cell.detailTextLabel.text = (pref == 1) ? @"iOS原生播放器" : @"自定义播放器";
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row == 0) {
        [self.navigationController pushViewController:[[SourceManagerViewController alloc] init] animated:YES];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"默认全屏逻辑" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"跟随系统", @"横屏", @"竖屏", nil];
            sheet.tag = 201; [sheet showInView:self.view];
        } else if (indexPath.row == 1) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"默认播放器" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"自定义播放器 (推荐)", @"iOS原生播放器", nil];
            sheet.tag = 202; [sheet showInView:self.view];
        } else if (indexPath.row == 2) {
            UAManagerViewController *uaVC = [[UAManagerViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:uaVC animated:YES];
        }
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        // 新增：跳转到数据管理页面
        DataManagementViewController *dataVC = [[DataManagementViewController alloc] init];
        [self.navigationController pushViewController:dataVC animated:YES];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        [self.navigationController pushViewController:[[AboutViewController alloc] init] animated:YES];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 201 && buttonIndex != actionSheet.cancelButtonIndex) {
        [[NSUserDefaults standardUserDefaults] setInteger:buttonIndex forKey:@"PlayerOrientationPref"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadData];
    } else if (actionSheet.tag == 202 && buttonIndex != actionSheet.cancelButtonIndex) {
        [[NSUserDefaults standardUserDefaults] setInteger:buttonIndex forKey:@"PlayerTypePref"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadData];
    }
}

@end