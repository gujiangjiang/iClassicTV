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
    return ([PlayerConfigManager preferredPlayerType] == 0) ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 1;
    if (section == 2) return 3; // [修改] 高级设置增加到 3 行（新增回放标识开关）
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
        // [修改] 更新底部提示文案包含回放标识说明
        return @"全屏状态下可附带显示节目单列表、右上角的悬浮时间以及左下角的回放标识。部分组件会跟随播放进度条同步显示与隐藏。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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
        } else if (indexPath.row == 2) {
            // [新增] 回放标识开关逻辑
            cell.textLabel.text = @"全屏状态显示回放标识";
            [switchView setOn:[PlayerConfigManager showCatchupBadgeInFullscreen] animated:NO];
            [switchView addTarget:self action:@selector(catchupBadgeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = switchView;
        
        return cell;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
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

// [新增] 回放标识开关交互动作
- (void)catchupBadgeSwitchChanged:(UISwitch *)sender {
    [PlayerConfigManager setShowCatchupBadgeInFullscreen:sender.isOn];
}

@end