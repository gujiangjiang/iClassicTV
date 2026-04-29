//
//  DataCleanupViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "DataCleanupViewController.h"
#import "AppDataManager.h"
#import "WatchListDataManager.h"
#import "EPGManager.h"
#import "AlertHelper.h"
#import "LanguageManager.h"

@interface DataCleanupViewController ()
@property (nonatomic, strong) NSArray *sections;
@end

@implementation DataCleanupViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // [新增] 设置下级菜单标题
    self.title = @"数据清理";
    
    // [优化] 转移过来的各项清理功能模型
    __weak typeof(self) weakSelf = self;
    self.sections = @[
                      @{
                          @"title": LocalizedString(@"data_management"), // 用于归纳日常操作产生的记录缓存
                          @"rows": @[
                                  @{ @"title": LocalizedString(@"clear_favorites"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_favorites") message:LocalizedString(@"confirm_clear_favorites_msg") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[WatchListDataManager sharedManager] clearFavorites];
                                          [weakSelf showSuccessAlert:LocalizedString(@"cleanup_complete")];
                                      } cancelBlock:nil];
                                  } },
                                  @{ @"title": LocalizedString(@"clear_recent_play"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_recent_play") message:LocalizedString(@"confirm_clear_recent_msg") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[WatchListDataManager sharedManager] clearRecentPlays];
                                          [weakSelf showSuccessAlert:LocalizedString(@"cleanup_complete")];
                                      } cancelBlock:nil];
                                  } },
                                  @{ @"title": LocalizedString(@"clear_appointments"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_appointments") message:LocalizedString(@"confirm_clear_appointments_msg") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[WatchListDataManager sharedManager] clearAppointments];
                                          [weakSelf showSuccessAlert:LocalizedString(@"cleanup_complete")];
                                      } cancelBlock:nil];
                                  } },
                                  @{ @"title": LocalizedString(@"clear_epg_cache"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"tips") message:LocalizedString(@"clear_epg_cache") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[EPGManager sharedManager] clearEPGCache];
                                          [weakSelf showSuccessAlert:LocalizedString(@"epg_cache_cleared")];
                                      } cancelBlock:nil];
                                  } },
                                  @{ @"title": LocalizedString(@"clear_all_icons"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_all_icons") message:LocalizedString(@"confirm_clear_icons") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[AppDataManager sharedManager] clearAllChannelIcons];
                                          [weakSelf showSuccessAlert:LocalizedString(@"all_icons_cleared")];
                                      } cancelBlock:nil];
                                  } },
                                  @{ @"title": LocalizedString(@"clear_all_cache"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_all_cache") message:LocalizedString(@"confirm_clear_cache") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[AppDataManager sharedManager] clearAllGeneralCache];
                                          [weakSelf showSuccessAlert:LocalizedString(@"cache_cleared")];
                                      } cancelBlock:nil];
                                  } }
                                  ]
                          },
                      @{
                          @"title": LocalizedString(@"data_cleanup_section"), // 涉及核心库和重置的危险操作
                          @"rows": @[
                                  @{ @"title": LocalizedString(@"clear_all_sources"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_all_sources") message:LocalizedString(@"confirm_clear_sources") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[AppDataManager sharedManager] clearAllSources];
                                          [weakSelf showSuccessAlert:LocalizedString(@"all_sources_cleared")];
                                      } cancelBlock:nil];
                                  } },
                                  @{ @"title": LocalizedString(@"clear_preferences"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_preferences") message:LocalizedString(@"confirm_clear_prefs") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[AppDataManager sharedManager] clearAllPreferencesCache];
                                          [weakSelf showSuccessAlert:LocalizedString(@"prefs_cleared")];
                                      } cancelBlock:nil];
                                  } },
                                  @{ @"title": LocalizedString(@"restore_all_settings"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"restore_all_settings") message:LocalizedString(@"confirm_restore_settings") confirmTitle:LocalizedString(@"confirm") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [[AppDataManager sharedManager] restoreAllSettings];
                                          [weakSelf showSuccessAlert:LocalizedString(@"settings_restored")];
                                      } cancelBlock:nil];
                                  } }
                                  ]
                          }
                      ];
}

- (void)showSuccessAlert:(NSString *)message {
    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:message delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
    [successAlert show];
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
    static NSString *CellIdentifier = @"DataCleanupCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *rowData = self.sections[indexPath.section][@"rows"][indexPath.row];
    cell.textLabel.text = rowData[@"title"];
    
    // 根据数据模型自动控制样式
    if ([rowData[@"isDanger"] boolValue]) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor redColor];
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 取出对应的 Block 直接执行对应逻辑，彻底消除 switch 的硬编码
    NSDictionary *rowData = self.sections[indexPath.section][@"rows"][indexPath.row];
    void(^actionBlock)(void) = rowData[@"action"];
    if (actionBlock) {
        actionBlock();
    }
}

@end