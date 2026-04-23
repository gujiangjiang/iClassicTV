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

#pragma mark - 设置主菜单 (SettingsViewController)
// =========================================================
@interface SettingsViewController () <UIAlertViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *sections;
@end

@implementation SettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    
    // 优化：精简主设置界面，将添加源的功能统一合并到我的直播源里面
    self.sections = @[
                      @{@"title": @"直播源设置", @"rows": @[@"我的直播源 (管理与添加)"]},
                      @{@"title": @"软件设置", @"rows": @[@"默认全屏逻辑", @"默认播放器", @"清空所有直播源", @"清空缓存 (记忆与偏好)"]},
                      @{@"title": @"关于", @"rows": @[@"关于 iClassicTV"]}
                      ];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *rows = self.sections[section][@"rows"];
    return rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSArray *rows = self.sections[indexPath.section][@"rows"];
    cell.textLabel.text = rows[indexPath.row];
    cell.detailTextLabel.text = @"";
    
    // 破坏性操作按钮标红
    if (indexPath.section == 1 && (indexPath.row == 2 || indexPath.row == 3)) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor redColor];
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    // 显示当前的“默认全屏逻辑”配置
    if (indexPath.section == 1 && indexPath.row == 0) {
        NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        if (pref == 1) {
            cell.detailTextLabel.text = @"横屏";
        } else if (pref == 2) {
            cell.detailTextLabel.text = @"竖屏";
        } else {
            cell.detailTextLabel.text = @"跟随系统";
        }
    }
    
    // 显示当前的“默认播放器”配置
    if (indexPath.section == 1 && indexPath.row == 1) {
        NSInteger playerPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerTypePref"];
        if (playerPref == 1) {
            cell.detailTextLabel.text = @"iOS原生播放器";
        } else {
            cell.detailTextLabel.text = @"自定义播放器";
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            // 跳转新的直播源管理页面
            SourceManagerViewController *smVC = [[SourceManagerViewController alloc] init];
            [self.navigationController pushViewController:smVC animated:YES];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"默认全屏逻辑" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"跟随系统", @"横屏", @"竖屏", nil];
            sheet.tag = 201;
            [sheet showInView:self.view];
        } else if (indexPath.row == 1) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"默认播放器" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"自定义播放器 (推荐)", @"iOS原生播放器", nil];
            sheet.tag = 202;
            [sheet showInView:self.view];
        } else if (indexPath.row == 2) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"警告" message:@"确定要清空所有的直播源吗？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定清空", nil];
            alert.tag = 101;
            [alert show];
        } else if (indexPath.row == 3) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"清空缓存" message:@"确定要清空所有的线路记忆偏好吗？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            alert.tag = 102;
            [alert show];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            AboutViewController *aboutVC = [[AboutViewController alloc] init];
            [self.navigationController pushViewController:aboutVC animated:YES];
        }
    }
}

#pragma mark - 底部菜单及警告框代理

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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        if (alertView.tag == 101) {
            // 一键清空所有数据
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ios6_iptv_sources"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ios6_iptv_active_source_id"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
            
            UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"所有直播源已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [successAlert show];
        } else if (alertView.tag == 102) {
            // 清理缓存
            NSDictionary *defaultsDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
            for (NSString *key in [defaultsDict allKeys]) {
                if ([key hasPrefix:@"SourcePref_"]) {
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
                }
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"记忆缓存已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [successAlert show];
        }
    }
}

@end