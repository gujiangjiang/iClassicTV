//
//  PlayerSettingsViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerSettingsViewController.h"
#import "PlayerConfigManager.h"
#import "LanguageManager.h"

@implementation PlayerSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"播放器设置";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // 只有当选择的是自定义播放器 (Type == 0) 时，才显示第三个区（高级设置）
    return ([PlayerConfigManager preferredPlayerType] == 0) ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2; // 播放器类型: 自定义、原生
    } else if (section == 1) {
        return 3; // 全屏逻辑: 跟随系统、默认横屏、默认竖屏
    } else if (section == 2) {
        return 2; // 自定义播放器高级设置: 显示节目单、显示时间
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"播放器选择";
    if (section == 1) return LocalizedString(@"default_fullscreen_logic");
    if (section == 2) return @"高级功能 (仅限自定义播放器)";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) {
        return @"全屏状态下可附带显示节目单列表及右上角的悬浮时间，这些控件会跟随播放进度条同步显示与隐藏。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PlayerSettingCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // 重置复用状态
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.textLabel.textColor = [UIColor blackColor];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = LocalizedString(@"custom_player_recommended");
            if ([PlayerConfigManager preferredPlayerType] == 0) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = LocalizedString(@"ios_native_player");
            if ([PlayerConfigManager preferredPlayerType] == 1) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
            }
        }
    } else if (indexPath.section == 1) {
        NSArray *titles = @[LocalizedString(@"follow_system"), LocalizedString(@"landscape"), LocalizedString(@"portrait")];
        cell.textLabel.text = titles[indexPath.row];
        
        if ([PlayerConfigManager preferredInterfaceOrientationPref] == indexPath.row) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
        }
    } else if (indexPath.section == 2) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"全屏状态显示节目单";
            [switchView setOn:[PlayerConfigManager showEPGInFullscreen] animated:NO];
            [switchView addTarget:self action:@selector(epgSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"全屏状态显示悬浮时间";
            [switchView setOn:[PlayerConfigManager showTimeInFullscreen] animated:NO];
            [switchView addTarget:self action:@selector(timeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = switchView;
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        [PlayerConfigManager setPreferredPlayerType:indexPath.row];
        // 播放器类型改变时，需要刷新整个列表以展示或隐藏 Section 2
        [tableView reloadData];
    } else if (indexPath.section == 1) {
        [PlayerConfigManager setPreferredInterfaceOrientationPref:indexPath.row];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - Switch Actions

- (void)epgSwitchChanged:(UISwitch *)sender {
    [PlayerConfigManager setShowEPGInFullscreen:sender.isOn];
}

- (void)timeSwitchChanged:(UISwitch *)sender {
    [PlayerConfigManager setShowTimeInFullscreen:sender.isOn];
}

@end