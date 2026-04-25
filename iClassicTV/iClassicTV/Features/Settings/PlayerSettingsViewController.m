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

// [修改] 增加 UIActionSheetDelegate 协议，用于处理弹出选项
@interface PlayerSettingsViewController () <UIActionSheetDelegate>
@end

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
    if (section == 0) return 1; // [修改] 播放器选择改为1行
    if (section == 1) return 1; // [修改] 全屏逻辑改为1行
    if (section == 2) return 2; // 自定义播放器高级设置: 显示节目单、显示时间
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
    // [修改] 区分不同类型的 Cell 样式
    if (indexPath.section == 0 || indexPath.section == 1) {
        static NSString *Value1CellId = @"Value1Cell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Value1CellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:Value1CellId];
        }
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = [UIColor blackColor];
        
        if (indexPath.section == 0) {
            cell.textLabel.text = @"播放器选择";
            cell.detailTextLabel.text = ([PlayerConfigManager preferredPlayerType] == 0) ? LocalizedString(@"custom_player_recommended") : LocalizedString(@"ios_native_player");
        } else if (indexPath.section == 1) {
            cell.textLabel.text = LocalizedString(@"default_fullscreen_logic");
            NSArray *titles = @[LocalizedString(@"follow_system"), LocalizedString(@"landscape"), LocalizedString(@"portrait")];
            cell.detailTextLabel.text = titles[[PlayerConfigManager preferredInterfaceOrientationPref]];
        }
        
        return cell;
    } else {
        static NSString *SwitchCellId = @"SwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SwitchCellId];
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = [UIColor blackColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
        
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
        
        return cell;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // [修改] 点击后弹出 ActionSheet 进行选择
    if (indexPath.section == 0) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"播放器选择"
                                                           delegate:self
                                                  cancelButtonTitle:LocalizedString(@"cancel")
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:LocalizedString(@"custom_player_recommended"), LocalizedString(@"ios_native_player"), nil];
        sheet.tag = 100;
        [sheet showInView:self.view];
    } else if (indexPath.section == 1) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"default_fullscreen_logic")
                                                           delegate:self
                                                  cancelButtonTitle:LocalizedString(@"cancel")
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:LocalizedString(@"follow_system"), LocalizedString(@"landscape"), LocalizedString(@"portrait"), nil];
        sheet.tag = 101;
        [sheet showInView:self.view];
    }
}

#pragma mark - UIActionSheetDelegate

// [新增] 处理选项结果并刷新表格
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    if (actionSheet.tag == 100) {
        [PlayerConfigManager setPreferredPlayerType:buttonIndex];
        [self.tableView reloadData];
    } else if (actionSheet.tag == 101) {
        [PlayerConfigManager setPreferredInterfaceOrientationPref:buttonIndex];
        [self.tableView reloadData];
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