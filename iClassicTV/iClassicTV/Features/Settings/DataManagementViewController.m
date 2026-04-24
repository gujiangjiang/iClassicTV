//
//  DataManagementViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "DataManagementViewController.h"
#import "AppDataManager.h"
#import "AlertHelper.h" // 新增：引入通用弹窗模块

@interface DataManagementViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *scannedBackupFiles; // 保存扫描到的备份文件名
@property (nonatomic, copy) NSString *selectedBackupFileName; // 选中的待恢复文件名
@end

@implementation DataManagementViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"数据管理与备份";
    
    // 优化：重新排版和细化数据清理项，加入本地备份清理
    self.sections = @[
                      @{@"title": @"配置备份与恢复 (iTunes共享空间)", @"rows": @[@"备份当前配置 (导出并分享)", @"从备份恢复配置 (从iTunes读取)", @"清空所有本地备份文件"]},
                      @{@"title": @"数据清理 (危险操作)", @"rows": @[@"清空所有直播源", @"清空所有频道图像", @"清空所有缓存", @"清空记忆与偏好", @"恢复所有设置"]}
                      ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.sections[section][@"rows"] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.sections[section][@"title"]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"备份将包含您添加的所有直播源、自定义的 User-Agent 列表以及全屏/播放器等设置偏好。导出的文件可通过 iTunes 文件共享进行管理，或在此处直接清空。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"DataManageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    
    cell.textLabel.text = self.sections[indexPath.section][@"rows"][indexPath.row];
    
    // 危险操作区域特殊标记（第2分组全部，以及第1分组的清空备份项）
    if (indexPath.section == 1 || (indexPath.section == 0 && indexPath.row == 2)) {
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
    __weak typeof(self) weakSelf = self;
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self performExportConfiguration];
        } else if (indexPath.row == 1) {
            [self scanAndPerformRestore];
        } else if (indexPath.row == 2) {
            // 优化：使用公共的 AlertHelper 封装确认逻辑
            [AlertHelper showConfirmAlertWithTitle:@"清空备份"
                                           message:@"确定要永久删除本设备上的所有备份文件吗？"
                                      confirmTitle:@"确定删除"
                                       cancelTitle:@"取消"
                                      confirmBlock:^{
                                          [weakSelf clearAllBackupFiles];
                                      } cancelBlock:nil];
        }
    } else if (indexPath.section == 1) {
        // 细化后的清理操作分配对应的确认逻辑（利用 Block 可以直接在此处理，无需维护繁杂的 switch case 和 tag）
        switch (indexPath.row) {
            case 0: {
                [AlertHelper showConfirmAlertWithTitle:@"清空直播源" message:@"确定要清空所有的直播源吗？" confirmTitle:@"确定" cancelTitle:@"取消" confirmBlock:^{
                    [[AppDataManager sharedManager] clearAllSources];
                    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"所有直播源已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                    [successAlert show];
                } cancelBlock:nil];
                break;
            }
            case 1: {
                [AlertHelper showConfirmAlertWithTitle:@"清空频道图像" message:@"确定要清空已缓存的频道图像吗？" confirmTitle:@"确定" cancelTitle:@"取消" confirmBlock:^{
                    [[AppDataManager sharedManager] clearAllChannelIcons];
                    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"所有频道图像缓存已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                    [successAlert show];
                } cancelBlock:nil];
                break;
            }
            case 2: {
                [AlertHelper showConfirmAlertWithTitle:@"清空所有缓存" message:@"确定要清空应用的所有网络和临时缓存吗？" confirmTitle:@"确定" cancelTitle:@"取消" confirmBlock:^{
                    [[AppDataManager sharedManager] clearAllGeneralCache];
                    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"应用缓存已完全清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                    [successAlert show];
                } cancelBlock:nil];
                break;
            }
            case 3: {
                [AlertHelper showConfirmAlertWithTitle:@"清空记忆偏好" message:@"确定要清空所有的线路记忆与播放偏好吗？" confirmTitle:@"确定" cancelTitle:@"取消" confirmBlock:^{
                    [[AppDataManager sharedManager] clearAllPreferencesCache];
                    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"记忆与偏好已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                    [successAlert show];
                } cancelBlock:nil];
                break;
            }
            case 4: {
                [AlertHelper showConfirmAlertWithTitle:@"恢复所有设置" message:@"确定要恢复所有设置到默认状态吗？(不影响直播源)" confirmTitle:@"确定" cancelTitle:@"取消" confirmBlock:^{
                    [[AppDataManager sharedManager] restoreAllSettings];
                    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已恢复" message:@"各项设置已恢复至默认" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                    [successAlert show];
                } cancelBlock:nil];
                break;
            }
        }
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
    
    NSString *msg = count > 0 ? [NSString stringWithFormat:@"成功清空了 %d 个备份文件", count] : @"没有找到需要清理的备份文件";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"清理完成" message:msg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alert show];
}

#pragma mark - 导出与分享逻辑
- (void)performExportConfiguration {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *backupData = [NSMutableDictionary dictionary];
    
    // 1. 收集需备份的数据
    NSArray *sources = [defs objectForKey:@"ios6_iptv_sources"];
    if (sources) backupData[@"ios6_iptv_sources"] = sources;
    
    NSString *activeId = [defs objectForKey:@"ios6_iptv_active_source_id"];
    if (activeId) backupData[@"ios6_iptv_active_source_id"] = activeId;
    
    NSArray *uaList = [defs objectForKey:@"kUAManagerListKey"];
    if (uaList) backupData[@"kUAManagerListKey"] = uaList;
    
    backupData[@"kUAManagerSelectedIndexKey"] = @([defs integerForKey:@"kUAManagerSelectedIndexKey"]);
    backupData[@"PlayerOrientationPref"] = @([defs integerForKey:@"PlayerOrientationPref"]);
    backupData[@"PlayerTypePref"] = @([defs integerForKey:@"PlayerTypePref"]);
    
    // 2. 转换为 JSON
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:backupData options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"导出失败" message:@"配置文件序列化失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // 3. 生成文件名并保存至 Documents (iTunes 文件共享目录)
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *fileName = [NSString stringWithFormat:@"iClassicTV_Backup_%@.json", [formatter stringFromDate:[NSDate date]]];
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [docDir stringByAppendingPathComponent:fileName];
    
    BOOL success = [jsonData writeToFile:filePath atomically:YES];
    if (success) {
        // 4. 调用原生分享组件
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"导出失败" message:@"无法将文件写入本地目录" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - 扫描与恢复逻辑
- (void)scanAndPerformRestore {
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docDir error:nil];
    NSMutableArray *jsonFiles = [NSMutableArray array];
    
    // 过滤出所有的 JSON 备份文件
    for (NSString *file in files) {
        if ([[file.pathExtension lowercaseString] isEqualToString:@"json"] && [file hasPrefix:@"iClassicTV_Backup_"]) {
            [jsonFiles addObject:file];
        }
    }
    
    if (jsonFiles.count == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"未找到备份文件" message:@"请先通过 iTunes 的【文件共享】功能，将备份的 json 文件拖入应用目录中。" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // 按照文件修改时间降序排序（最新的在最前）
    [jsonFiles sortUsingComparator:^NSComparisonResult(NSString *file1, NSString *file2) {
        NSString *path1 = [docDir stringByAppendingPathComponent:file1];
        NSString *path2 = [docDir stringByAppendingPathComponent:file2];
        NSDictionary *attr1 = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:nil];
        NSDictionary *attr2 = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:nil];
        return [attr2.fileModificationDate compare:attr1.fileModificationDate];
    }];
    
    self.scannedBackupFiles = jsonFiles;
    
    // 如果只有一个文件，直接提示确认恢复；否则弹出列表让用户选择
    if (jsonFiles.count == 1) {
        self.selectedBackupFileName = jsonFiles.firstObject;
        [self showRestoreConfirmationAlert];
    } else {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"选择要恢复的备份文件" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        // 为了防止界面过长，最多显示最近的 5 个备份
        NSInteger displayCount = MIN(jsonFiles.count, 5);
        for (NSInteger i = 0; i < displayCount; i++) {
            [sheet addButtonWithTitle:jsonFiles[i]];
        }
        [sheet addButtonWithTitle:@"取消"];
        sheet.cancelButtonIndex = displayCount;
        sheet.tag = 301;
        [sheet showInView:self.view];
    }
}

- (void)showRestoreConfirmationAlert {
    NSString *msg = [NSString stringWithFormat:@"确定要恢复备份文件 [%@] 吗？\n当前的所有设置和直播源将被完全覆盖！", self.selectedBackupFileName];
    
    // 优化：使用公共的 AlertHelper 封装恢复确认
    __weak typeof(self) weakSelf = self;
    [AlertHelper showConfirmAlertWithTitle:@"确认恢复"
                                   message:msg
                              confirmTitle:@"立即恢复"
                               cancelTitle:@"取消"
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
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"恢复失败" message:@"备份文件格式不正确或已损坏" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // 开始写入恢复数据
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    if (backupData[@"ios6_iptv_sources"]) [defs setObject:backupData[@"ios6_iptv_sources"] forKey:@"ios6_iptv_sources"];
    if (backupData[@"ios6_iptv_active_source_id"]) [defs setObject:backupData[@"ios6_iptv_active_source_id"] forKey:@"ios6_iptv_active_source_id"];
    if (backupData[@"kUAManagerListKey"]) [defs setObject:backupData[@"kUAManagerListKey"] forKey:@"kUAManagerListKey"];
    if (backupData[@"kUAManagerSelectedIndexKey"]) [defs setInteger:[backupData[@"kUAManagerSelectedIndexKey"] integerValue] forKey:@"kUAManagerSelectedIndexKey"];
    if (backupData[@"PlayerOrientationPref"]) [defs setInteger:[backupData[@"PlayerOrientationPref"] integerValue] forKey:@"PlayerOrientationPref"];
    if (backupData[@"PlayerTypePref"]) [defs setInteger:[backupData[@"PlayerTypePref"] integerValue] forKey:@"PlayerTypePref"];
    
    [defs synchronize];
    
    // 通知全局数据刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    
    UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"恢复成功" message:@"配置已成功恢复！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [successAlert show];
}

#pragma mark - 动作表代理
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 301 && buttonIndex != actionSheet.cancelButtonIndex) {
        self.selectedBackupFileName = self.scannedBackupFiles[buttonIndex];
        [self showRestoreConfirmationAlert];
    }
}

// 注：由于所有清空和确认操作已被 AlertHelper 的 Block 接管，原有的 UIAlertViewDelegate 方法被完全精简，移除了冗杂的 tag 判断

@end