//
//  FeatureSettingsViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "FeatureSettingsViewController.h"
#import "PlayerConfigManager.h"
#import "WatchListDataManager.h"
#import "LanguageManager.h"
#import "ToastHelper.h"

@interface FeatureSettingsViewController () <UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, assign) NSInteger pendingRecordMode; // 用于暂存即将切换的记录模式
@end

@implementation FeatureSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"feature_settings");
    [self setupSections];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)setupSections {
    // [优化] 添加新版收藏与记录模式设置项
    self.sections = @[
                      @{@"title": LocalizedString(@"watchlist.my_tv"), @"rows": @[LocalizedString(@"watchlist.favorites"), LocalizedString(@"watchlist.recent_play")]},
                      @{@"title": LocalizedString(@"feature_settings"), @"rows": @[LocalizedString(@"default_startup_page"), LocalizedString(@"recent_play_limit"), LocalizedString(@"watchlist.record_mode")]},
                      @{@"title": LocalizedString(@"data_management"), @"rows": @[LocalizedString(@"clear_favorites"), LocalizedString(@"clear_recent_play"), LocalizedString(@"clear_appointments")]}
                      ];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"FeatureSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.text = self.sections[indexPath.section][@"rows"][indexPath.row];
    cell.detailTextLabel.text = @"";
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    if (indexPath.section == 0) {
        // 我的电视功能开关
        UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
        switchView.tag = indexPath.row;
        [switchView addTarget:self action:@selector(watchListSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        
        if (indexPath.row == 0) {
            switchView.on = [PlayerConfigManager enableFavoritesTab];
        } else if (indexPath.row == 1) {
            switchView.on = [PlayerConfigManager enableRecentPlayTab];
        }
        cell.accessoryView = switchView;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 1) {
        // 功能设置项
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (indexPath.row == 0) {
            NSInteger page = [PlayerConfigManager defaultStartupPage];
            cell.detailTextLabel.text = (page == 0) ? LocalizedString(@"channel_list") : LocalizedString(@"watchlist.my_tv");
        } else if (indexPath.row == 1) {
            NSInteger limit = [PlayerConfigManager recentPlayLimit];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)limit];
        } else if (indexPath.row == 2) {
            // [新增] 记录模式显示
            NSInteger mode = [PlayerConfigManager watchListRecordMode];
            cell.detailTextLabel.text = (mode == 0) ? LocalizedString(@"watchlist.record_mode_channel") : LocalizedString(@"watchlist.record_mode_url");
        }
    } else if (indexPath.section == 2) {
        // 数据清理项
        cell.textLabel.textColor = [UIColor redColor];
    }
    
    return cell;
}

- (void)watchListSwitchChanged:(UISwitch *)sender {
    if (sender.tag == 0) {
        [PlayerConfigManager setEnableFavoritesTab:sender.on];
    } else if (sender.tag == 1) {
        [PlayerConfigManager setEnableRecentPlayTab:sender.on];
        // 当关闭最近播放功能时，自动清空所有最近播放记录
        if (!sender.on) {
            [[WatchListDataManager sharedManager] clearRecentPlays];
        }
    }
    // 发送全局通知，触发表单结构与Tab展现逻辑刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchListVisibilityDidChangeNotification" object:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"default_startup_page") delegate:self cancelButtonTitle:LocalizedString(@"cancel") destructiveButtonTitle:nil otherButtonTitles:LocalizedString(@"channel_list"), LocalizedString(@"watchlist.my_tv"), nil];
            sheet.tag = 201;
            [sheet showInView:self.view];
        } else if (indexPath.row == 1) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"recent_play_limit")
                                                            message:LocalizedString(@"enter_limit_1_to_50")
                                                           delegate:self
                                                  cancelButtonTitle:LocalizedString(@"cancel")
                                                  otherButtonTitles:LocalizedString(@"confirm"), nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            UITextField *textField = [alert textFieldAtIndex:0];
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.text = [NSString stringWithFormat:@"%ld", (long)[PlayerConfigManager recentPlayLimit]];
            alert.tag = 301;
            [alert show];
        } else if (indexPath.row == 2) {
            // [新增] 记录模式选择ActionSheet
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"watchlist.record_mode") delegate:self cancelButtonTitle:LocalizedString(@"cancel") destructiveButtonTitle:nil otherButtonTitles:LocalizedString(@"watchlist.record_mode_channel"), LocalizedString(@"watchlist.record_mode_url"), nil];
            sheet.tag = 202;
            [sheet showInView:self.view];
        }
    } else if (indexPath.section == 2) {
        NSString *title = LocalizedString(@"tips");
        NSString *message = @"";
        NSInteger tag = 0;
        
        if (indexPath.row == 0) {
            message = LocalizedString(@"confirm_clear_favorites_msg");
            tag = 101;
        } else if (indexPath.row == 1) {
            message = LocalizedString(@"confirm_clear_recent_msg");
            tag = 102;
        } else if (indexPath.row == 2) {
            message = LocalizedString(@"confirm_clear_appointments_msg");
            tag = 103;
        }
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:LocalizedString(@"cancel") otherButtonTitles:LocalizedString(@"confirm"), nil];
        alert.tag = tag;
        [alert show];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    if (actionSheet.tag == 201) {
        [PlayerConfigManager setDefaultStartupPage:buttonIndex];
        [self.tableView reloadData];
    } else if (actionSheet.tag == 202) {
        // [新增] 处理记录模式的切换选项
        NSInteger newMode = buttonIndex;
        NSInteger currentMode = [PlayerConfigManager watchListRecordMode];
        // 如果选择的内容不一致，需要弹窗提示清空数据
        if (newMode != currentMode) {
            self.pendingRecordMode = newMode;
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"watchlist.confirm_switch_mode_title") message:LocalizedString(@"watchlist.confirm_switch_mode_msg") delegate:self cancelButtonTitle:LocalizedString(@"cancel") otherButtonTitles:LocalizedString(@"confirm"), nil];
            alert.tag = 401; // 特殊的tag标识模式切换警告
            [alert show];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // 确认按钮
        if (alertView.tag == 101) {
            [[WatchListDataManager sharedManager] clearFavorites];
            UIAlertView *toast = [[UIAlertView alloc] initWithTitle:nil message:LocalizedString(@"cleanup_complete") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
            [toast show];
        } else if (alertView.tag == 102) {
            [[WatchListDataManager sharedManager] clearRecentPlays];
            UIAlertView *toast = [[UIAlertView alloc] initWithTitle:nil message:LocalizedString(@"cleanup_complete") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
            [toast show];
        } else if (alertView.tag == 103) {
            [[WatchListDataManager sharedManager] clearAppointments];
            UIAlertView *toast = [[UIAlertView alloc] initWithTitle:nil message:LocalizedString(@"cleanup_complete") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
            [toast show];
        } else if (alertView.tag == 301) {
            UITextField *textField = [alertView textFieldAtIndex:0];
            NSInteger limit = [textField.text integerValue];
            if (limit >= 1 && limit <= 50) {
                [PlayerConfigManager setRecentPlayLimit:limit];
                [self.tableView reloadData];
            } else {
                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips")
                                                                     message:LocalizedString(@"invalid_limit_msg")
                                                                    delegate:nil
                                                           cancelButtonTitle:LocalizedString(@"confirm")
                                                           otherButtonTitles:nil];
                [errorAlert show];
            }
        } else if (alertView.tag == 401) {
            // [新增] 确认切换记录模式，并清空所有相关数据，保护数据一致性
            [[WatchListDataManager sharedManager] clearFavorites];
            [[WatchListDataManager sharedManager] clearRecentPlays];
            [[WatchListDataManager sharedManager] clearAppointments];
            [PlayerConfigManager setWatchListRecordMode:self.pendingRecordMode];
            [self.tableView reloadData];
            [ToastHelper showToastWithMessage:LocalizedString(@"cleanup_complete")];
        }
    }
}

@end