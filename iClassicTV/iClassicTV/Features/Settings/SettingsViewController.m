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
#import "AppDataManager.h" // 引入数据管理模块

@interface SettingsViewController () <UIAlertViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *sections;
@end

@implementation SettingsViewController

- (instancetype)init { self = [super initWithStyle:UITableViewStyleGrouped]; return self; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    self.sections = @[
                      @{@"title": @"直播源设置", @"rows": @[@"我的直播源 (管理与添加)"]},
                      @{@"title": @"软件设置", @"rows": @[@"默认全屏逻辑", @"默认播放器", @"清空所有直播源", @"清空缓存 (记忆与偏好)"]},
                      @{@"title": @"关于", @"rows": @[@"关于 iClassicTV"]}
                      ];
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
    
    if (indexPath.section == 1 && (indexPath.row == 2 || indexPath.row == 3)) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor redColor];
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    if (indexPath.section == 1 && indexPath.row == 0) {
        NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        cell.detailTextLabel.text = (pref == 1) ? @"横屏" : ((pref == 2) ? @"竖屏" : @"跟随系统");
    }
    if (indexPath.section == 1 && indexPath.row == 1) {
        NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerTypePref"];
        cell.detailTextLabel.text = (pref == 1) ? @"iOS原生播放器" : @"自定义播放器";
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
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"警告" message:@"确定要清空所有的直播源吗？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定清空", nil];
            alert.tag = 101; [alert show];
        } else if (indexPath.row == 3) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"清空缓存" message:@"确定要清空所有的线路记忆偏好吗？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            alert.tag = 102; [alert show];
        }
    } else if (indexPath.section == 2 && indexPath.row == 0) {
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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        if (alertView.tag == 101) {
            // 调用模块一键清理所有数据
            [[AppDataManager sharedManager] clearAllSources];
            UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"所有直播源已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [successAlert show];
        } else if (alertView.tag == 102) {
            // 调用模块清理偏好缓存
            [[AppDataManager sharedManager] clearAllPreferencesCache];
            UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"记忆缓存已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [successAlert show];
        }
    }
}
@end