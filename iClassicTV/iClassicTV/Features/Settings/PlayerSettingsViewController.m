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
        self.title = LocalizedString(@"player_settings_title");
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // 优化：原生播放器只显示1个分区（播放器选择）；自定义播放器显示2个分区（包含高级设置）
    return ([PlayerConfigManager preferredPlayerType] == 0) ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    // 分区1（仅自定义播放器显示）：包含 1个点击选择单元格(全屏逻辑) + 4个开关单元格 [修改]
    if (section == 1) return 5;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return LocalizedString(@"player_selection");
    if (section == 1) return LocalizedString(@"advanced_features_custom_only");
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return LocalizedString(@"fullscreen_widgets_footer");
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *Value1CellId = @"Value1Cell_Player";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Value1CellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:Value1CellId];
        }
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = [UIColor blackColor];
        
        cell.textLabel.text = LocalizedString(@"player_selection");
        cell.detailTextLabel.text = ([PlayerConfigManager preferredPlayerType] == 0) ? LocalizedString(@"custom_player_recommended") : LocalizedString(@"ios_native_player");
        
        return cell;
        
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            // 第一行：默认全屏逻辑
            static NSString *Value1CellId = @"Value1Cell_Logic";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Value1CellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:Value1CellId];
            }
            
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.textColor = [UIColor blackColor];
            
            cell.textLabel.text = LocalizedString(@"default_fullscreen_logic");
            NSArray *titles = @[LocalizedString(@"follow_system"), LocalizedString(@"landscape"), LocalizedString(@"portrait")];
            cell.detailTextLabel.text = titles[[PlayerConfigManager preferredInterfaceOrientationPref]];
            
            return cell;
        } else {
            // 后四行：全屏显示小部件的开关
            static NSString *SwitchCellId = @"SwitchCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SwitchCellId];
            }
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textColor = [UIColor blackColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
            if (indexPath.row == 1) {
                cell.textLabel.text = LocalizedString(@"show_epg_in_fullscreen");
                [switchView setOn:[PlayerConfigManager showEPGInFullscreen] animated:NO];
                [switchView addTarget:self action:@selector(epgSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = LocalizedString(@"show_time_in_fullscreen");
                [switchView setOn:[PlayerConfigManager showTimeInFullscreen] animated:NO];
                [switchView addTarget:self action:@selector(timeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = LocalizedString(@"show_catchup_badge_in_fullscreen");
                [switchView setOn:[PlayerConfigManager showCatchupBadgeInFullscreen] animated:NO];
                [switchView addTarget:self action:@selector(catchupBadgeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            } else if (indexPath.row == 4) { // [新增]
                cell.textLabel.text = LocalizedString(@"show_network_speed_in_fullscreen");
                [switchView setOn:[PlayerConfigManager showNetworkSpeedInFullscreen] animated:NO];
                [switchView addTarget:self action:@selector(networkSpeedSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            }
            cell.accessoryView = switchView;
            
            return cell;
        }
    }
    
    return [[UITableViewCell alloc] init];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row == 0) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"player_selection")
                                                           delegate:self
                                                  cancelButtonTitle:LocalizedString(@"cancel")
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:LocalizedString(@"custom_player_recommended"), LocalizedString(@"ios_native_player"), nil];
        sheet.tag = 100;
        [sheet showInView:self.view];
    } else if (indexPath.section == 1 && indexPath.row == 0) {
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

- (void)catchupBadgeSwitchChanged:(UISwitch *)sender {
    [PlayerConfigManager setShowCatchupBadgeInFullscreen:sender.isOn];
}

// [新增]
- (void)networkSpeedSwitchChanged:(UISwitch *)sender {
    [PlayerConfigManager setShowNetworkSpeedInFullscreen:sender.isOn];
}

@end