//
//  DataManagementViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "DataManagementViewController.h"
#import "AlertHelper.h"
#import "LanguageManager.h"
#import "DataCleanupViewController.h" // [新增] 引入下一级数据清理菜单

@interface DataManagementViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *scannedBackupFiles;
@property (nonatomic, copy) NSString *selectedBackupFileName;
@end

@implementation DataManagementViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"data_management_and_backup");
    
    __weak typeof(self) weakSelf = self;
    
    // [优化] 将具体清理项移出，新增入口跳转到下一级菜单
    self.sections = @[
                      @{
                          @"title": LocalizedString(@"backup_restore_section"),
                          @"rows": @[
                                  @{ @"title": LocalizedString(@"backup_current"), @"isDanger": @NO, @"action": ^{ [weakSelf performExportConfiguration]; } },
                                  @{ @"title": LocalizedString(@"restore_from_backup"), @"isDanger": @NO, @"action": ^{ [weakSelf scanAndPerformRestore]; } },
                                  @{ @"title": LocalizedString(@"clear_all_backups"), @"isDanger": @YES, @"action": ^{
                                      [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"clear_all_backups") message:LocalizedString(@"confirm_clear_backups") confirmTitle:LocalizedString(@"delete") cancelTitle:LocalizedString(@"cancel") confirmBlock:^{
                                          [weakSelf clearAllBackupFiles];
                                      } cancelBlock:nil];
                                  } }
                                  ]
                          },
                      @{
                          @"title": @"数据清理", // [新增] 新的数据清理分区
                          @"rows": @[
                                  @{ @"title": @"数据清理", @"isDanger": @NO, @"action": ^{
                                      // [新增] 响应点击跳转到新建的清理二级菜单
                                      DataCleanupViewController *cleanupVC = [[DataCleanupViewController alloc] init];
                                      [weakSelf.navigationController pushViewController:cleanupVC animated:YES];
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

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return LocalizedString(@"backup_footer_desc");
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"DataManageCell";
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

#pragma mark - 清空备份逻辑
- (void)clearAllBackupFiles {
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docDir error:nil];
    int count = 0;
    
    for (NSString *file in files) {
        if ([[file.pathExtension lowercaseString] isEqualToString:@"json"] && [file hasPrefix:@"iClassicTV_Backup_"]) {
            NSString *filePath = [docDir stringByAppendingPathComponent:file];
            if ([[NSFileManager defaultManager] removeItemAtPath:filePath error:nil]) {
                count++;
            }
        }
    }
    
    NSString *msg = count > 0 ? [NSString stringWithFormat:LocalizedString(@"cleared_n_backups"), count] : LocalizedString(@"no_backups_to_clear");
    [self showSuccessAlert:msg];
}

#pragma mark - 导出与分享逻辑
- (void)performExportConfiguration {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *backupData = [NSMutableDictionary dictionary];
    
    NSArray *sources = [defs objectForKey:@"ios6_iptv_sources"];
    if (sources) backupData[@"ios6_iptv_sources"] = sources;
    
    NSString *activeId = [defs objectForKey:@"ios6_iptv_active_source_id"];
    if (activeId) backupData[@"ios6_iptv_active_source_id"] = activeId;
    
    NSArray *uaList = [defs objectForKey:@"kUAManagerListKey"];
    if (uaList) backupData[@"kUAManagerListKey"] = uaList;
    
    backupData[@"kUAManagerSelectedIndexKey"] = @([defs integerForKey:@"kUAManagerSelectedIndexKey"]);
    backupData[@"PlayerOrientationPref"] = @([defs integerForKey:@"PlayerOrientationPref"]);
    backupData[@"PlayerTypePref"] = @([defs integerForKey:@"PlayerTypePref"]);
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:backupData options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"export_failed") message:LocalizedString(@"config_serialize_failed") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *fileName = [NSString stringWithFormat:@"iClassicTV_Backup_%@.json", [formatter stringFromDate:[NSDate date]]];
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [docDir stringByAppendingPathComponent:fileName];
    
    BOOL success = [jsonData writeToFile:filePath atomically:YES];
    if (success) {
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"export_failed") message:LocalizedString(@"cannot_write_local") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - 扫描与恢复逻辑
- (void)scanAndPerformRestore {
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docDir error:nil];
    NSMutableArray *jsonFiles = [NSMutableArray array];
    
    for (NSString *file in files) {
        if ([[file.pathExtension lowercaseString] isEqualToString:@"json"] && [file hasPrefix:@"iClassicTV_Backup_"]) {
            [jsonFiles addObject:file];
        }
    }
    
    if (jsonFiles.count == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"no_backup_found") message:LocalizedString(@"please_import_backup") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [jsonFiles sortUsingComparator:^NSComparisonResult(NSString *file1, NSString *file2) {
        NSString *path1 = [docDir stringByAppendingPathComponent:file1];
        NSString *path2 = [docDir stringByAppendingPathComponent:file2];
        NSDictionary *attr1 = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:nil];
        NSDictionary *attr2 = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:nil];
        return [attr2.fileModificationDate compare:attr1.fileModificationDate];
    }];
    
    self.scannedBackupFiles = jsonFiles;
    
    if (jsonFiles.count == 1) {
        self.selectedBackupFileName = jsonFiles.firstObject;
        [self showRestoreConfirmationAlert];
    } else {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"select_backup_to_restore") delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        NSInteger displayCount = MIN(jsonFiles.count, 5);
        for (NSInteger i = 0; i < displayCount; i++) {
            [sheet addButtonWithTitle:jsonFiles[i]];
        }
        [sheet addButtonWithTitle:LocalizedString(@"cancel")];
        sheet.cancelButtonIndex = displayCount;
        sheet.tag = 301;
        [sheet showInView:self.view];
    }
}

- (void)showRestoreConfirmationAlert {
    NSString *msg = [NSString stringWithFormat:LocalizedString(@"confirm_restore_msg"), self.selectedBackupFileName];
    
    __weak typeof(self) weakSelf = self;
    [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"confirm_restore")
                                   message:msg
                              confirmTitle:LocalizedString(@"restore_now")
                               cancelTitle:LocalizedString(@"cancel")
                              confirmBlock:^{
                                  [weakSelf executeRestore];
                              } cancelBlock:nil];
}

- (void)executeRestore {
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [docDir stringByAppendingPathComponent:self.selectedBackupFileName];
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath];
    
    if (!jsonData) return;
    
    NSError *error = nil;
    NSDictionary *backupData = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
    
    if (error || ![backupData isKindOfClass:[NSDictionary class]]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"restore_failed") message:LocalizedString(@"backup_invalid") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    if (backupData[@"ios6_iptv_sources"]) [defs setObject:backupData[@"ios6_iptv_sources"] forKey:@"ios6_iptv_sources"];
    if (backupData[@"ios6_iptv_active_source_id"]) [defs setObject:backupData[@"ios6_iptv_active_source_id"] forKey:@"ios6_iptv_active_source_id"];
    if (backupData[@"kUAManagerListKey"]) [defs setObject:backupData[@"kUAManagerListKey"] forKey:@"kUAManagerListKey"];
    if (backupData[@"kUAManagerSelectedIndexKey"]) [defs setInteger:[backupData[@"kUAManagerSelectedIndexKey"] integerValue] forKey:@"kUAManagerSelectedIndexKey"];
    if (backupData[@"PlayerOrientationPref"]) [defs setInteger:[backupData[@"PlayerOrientationPref"] integerValue] forKey:@"PlayerOrientationPref"];
    if (backupData[@"PlayerTypePref"]) [defs setInteger:[backupData[@"PlayerTypePref"] integerValue] forKey:@"PlayerTypePref"];
    
    [defs synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    
    [self showSuccessAlert:LocalizedString(@"config_restored")];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 301 && buttonIndex != actionSheet.cancelButtonIndex) {
        self.selectedBackupFileName = self.scannedBackupFiles[buttonIndex];
        [self showRestoreConfirmationAlert];
    }
}

@end