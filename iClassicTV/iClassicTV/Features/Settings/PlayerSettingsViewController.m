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
    return ([PlayerConfigManager preferredPlayerType] == 0) ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 1;
    if (section == 2) return 3;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return LocalizedString(@"player_selection");
    if (section == 1) return LocalizedString(@"default_fullscreen_logic");
    if (section == 2) return LocalizedString(@"advanced_features_custom_only");
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) {
        return LocalizedString(@"fullscreen_widgets_footer");
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
            cell.textLabel.text = LocalizedString(@"player_selection");
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
            cell.textLabel.text = LocalizedString(@"show_epg_in_fullscreen");
            [switchView setOn:[PlayerConfigManager showEPGInFullscreen] animated:NO];
            [switchView addTarget:self action:@selector(epgSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = LocalizedString(@"show_time_in_fullscreen");
            [switchView setOn:[PlayerConfigManager showTimeInFullscreen] animated:NO];
            [switchView addTarget:self action:@selector(timeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if (indexPath.row == 2) {
            cell.textLabel.text = LocalizedString(@"show_catchup_badge_in_fullscreen");
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
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"player_selection")
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

- (void)catchupBadgeSwitchChanged:(UISwitch *)sender {
    [PlayerConfigManager setShowCatchupBadgeInFullscreen:sender.isOn];
}

@end