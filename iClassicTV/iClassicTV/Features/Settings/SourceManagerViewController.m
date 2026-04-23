//
//  SourceManagerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "SourceManagerViewController.h"
#import "TextImportModalViewController.h"

#pragma mark - 内部工具方法：添加新的直播源 (修改为接收指定名称)
// =========================================================
static void addNewSource(NSString *sourceName, NSString *m3uData, NSString *urlString) {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *sources = [[defs objectForKey:@"ios6_iptv_sources"] mutableCopy] ?: [NSMutableArray array];
    
    NSString *sourceId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *source = @{
                             @"id": sourceId,
                             @"name": sourceName ?: @"未命名直播源",
                             @"content": m3uData ?: @"",
                             @"url": urlString ?: @""
                             };
    
    [sources addObject:source];
    [defs setObject:sources forKey:@"ios6_iptv_sources"];
    
    // 如果这是唯一的一个源，则自动设为当前激活源
    if (sources.count == 1) {
        [defs setObject:sourceId forKey:@"ios6_iptv_active_source_id"];
    }
    
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
}

@implementation SourceManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"我的直播源";
    
    // 优化：右上角添加 + 按钮
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddOptions)];
    self.navigationItem.rightBarButtonItem = addBtn;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.sources = [[[NSUserDefaults standardUserDefaults] objectForKey:@"ios6_iptv_sources"] mutableCopy] ?: [NSMutableArray array];
    [self.tableView reloadData];
}

- (void)showAddOptions {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"添加直播源" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"添加网络直播源", @"添加本地文本源", nil];
    sheet.tag = 101; // 利用 Tag 区分是“添加源菜单”还是“源操作菜单”
    [sheet showInView:self.view];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sources.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"SourceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }
    
    NSDictionary *source = self.sources[indexPath.row];
    cell.textLabel.text = source[@"name"];
    
    // 标记当前正在使用的源
    NSString *activeId = [[NSUserDefaults standardUserDefaults] objectForKey:@"ios6_iptv_active_source_id"];
    if ([source[@"id"] isEqualToString:activeId]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    if ([source[@"url"] length] > 0) {
        cell.detailTextLabel.text = source[@"url"];
    } else {
        cell.detailTextLabel.text = @"本地文本导入";
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.selectedIndexPath = indexPath;
    NSDictionary *source = self.sources[indexPath.row];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"操作" delegate:self cancelButtonTitle:nil destructiveButtonTitle:@"删除" otherButtonTitles:@"设为当前源", @"重命名", nil];
    
    if ([source[@"url"] length] > 0) {
        [sheet addButtonWithTitle:@"刷新同步"];
    }
    [sheet addButtonWithTitle:@"取消"];
    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    
    sheet.tag = 100; // 操作菜单的 Tag
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    // 针对 右上角 + 按钮 呼出的菜单
    if (actionSheet.tag == 101) {
        if (buttonIndex == 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"网络直播源" message:@"请输入 M3U 网址 (http://...)" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"下载", nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            [alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeURL;
            alert.tag = 201; // 网络导入URL输入弹窗
            [alert show];
        } else if (buttonIndex == 1) {
            // 优化：不再使用单行 UIAlertView，改为弹出专门的多行文本编辑模态页面
            TextImportModalViewController *textVC = [[TextImportModalViewController alloc] init];
            textVC.completionHandler = ^(NSString *text) {
                self.tempM3UData = text;
                self.tempURLString = @"";
                [self showNamingAlertWithTag:204]; // 数据接收成功，弹出命名弹窗
            };
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:textVC];
            [self presentViewController:nav animated:YES completion:nil];
        }
        return;
    }
    
    // 针对 点击单元格 呼出的操作菜单
    if (actionSheet.tag == 100) {
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        NSMutableDictionary *source = [self.sources[self.selectedIndexPath.row] mutableCopy];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        
        if ([title isEqualToString:@"删除"]) {
            [self.sources removeObjectAtIndex:self.selectedIndexPath.row];
            [defs setObject:self.sources forKey:@"ios6_iptv_sources"];
            
            if ([source[@"id"] isEqualToString:[defs objectForKey:@"ios6_iptv_active_source_id"]]) {
                if (self.sources.count > 0) {
                    [defs setObject:self.sources.firstObject[@"id"] forKey:@"ios6_iptv_active_source_id"];
                } else {
                    [defs removeObjectForKey:@"ios6_iptv_active_source_id"];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
            }
            [defs synchronize];
            [self.tableView reloadData];
            
        } else if ([title isEqualToString:@"设为当前源"]) {
            [defs setObject:source[@"id"] forKey:@"ios6_iptv_active_source_id"];
            [defs synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
            [self.tableView reloadData];
            [self showToast:@"已切换直播源"];
            
        } else if ([title isEqualToString:@"重命名"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"重命名" message:@"请输入新的名称" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            UITextField *tf = [alert textFieldAtIndex:0];
            tf.text = source[@"name"];
            alert.tag = 301;
            [alert show];
            
        } else if ([title isEqualToString:@"刷新同步"]) {
            [self refreshSource:source atIndex:self.selectedIndexPath.row];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) return;
    
    if (alertView.tag == 301) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        if (tf.text.length > 0) {
            NSMutableDictionary *source = [self.sources[self.selectedIndexPath.row] mutableCopy];
            source[@"name"] = tf.text;
            self.sources[self.selectedIndexPath.row] = source;
            
            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            [defs setObject:self.sources forKey:@"ios6_iptv_sources"];
            [defs synchronize];
            [self.tableView reloadData];
            
            if ([source[@"id"] isEqualToString:[defs objectForKey:@"ios6_iptv_active_source_id"]]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
            }
        }
    } else if (alertView.tag == 201) {
        // 处理输入的网络URL
        NSString *urlStr = [alertView textFieldAtIndex:0].text;
        NSURL *url = [NSURL URLWithString:urlStr];
        if (!url) {
            [self showToast:@"网址无效"];
            return;
        }
        
        UIAlertView *hud = [[UIAlertView alloc] initWithTitle:@"下载中..." message:@"请稍候\n\n" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
        [hud show];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            NSString *m3uData = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud dismissWithClickedButtonIndex:0 animated:YES];
                if (m3uData) {
                    self.tempM3UData = m3uData;
                    self.tempURLString = urlStr;
                    [self showNamingAlertWithTag:203]; // 下载成功，弹出命名弹窗
                } else {
                    [self showToast:@"下载失败，请检查网络"];
                }
            });
        });
    } else if (alertView.tag == 203 || alertView.tag == 204) {
        // 保存新添加的直播源 (网络/文本 统一在此处处理)
        NSString *name = [alertView textFieldAtIndex:0].text;
        if (name.length == 0) name = @"未命名直播源";
        
        addNewSource(name, self.tempM3UData, self.tempURLString);
        [self showToast:@"直播源已成功保存！"];
        
        // 重新读取并刷新列表
        self.sources = [[[NSUserDefaults standardUserDefaults] objectForKey:@"ios6_iptv_sources"] mutableCopy] ?: [NSMutableArray array];
        [self.tableView reloadData];
    }
}

// 新增辅助方法：显示给直播源命名的弹窗
- (void)showNamingAlertWithTag:(NSInteger)tag {
    UIAlertView *nameAlert = [[UIAlertView alloc] initWithTitle:@"保存直播源" message:@"请为该直播源命名" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
    nameAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    
    // 默认提供一个以当前时间命名的预设
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [nameAlert textFieldAtIndex:0].text = [df stringFromDate:[NSDate date]];
    
    nameAlert.tag = tag;
    [nameAlert show];
}

- (void)refreshSource:(NSDictionary *)source atIndex:(NSInteger)index {
    NSURL *url = [NSURL URLWithString:source[@"url"]];
    if (!url) return;
    
    UIAlertView *hud = [[UIAlertView alloc] initWithTitle:@"刷新中..." message:@"请稍候\n\n" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [hud show];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *m3uData = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismissWithClickedButtonIndex:0 animated:YES];
            if (m3uData) {
                NSMutableDictionary *updatedSource = [source mutableCopy];
                updatedSource[@"content"] = m3uData;
                self.sources[index] = updatedSource;
                
                [[NSUserDefaults standardUserDefaults] setObject:self.sources forKey:@"ios6_iptv_sources"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                if ([source[@"id"] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"ios6_iptv_active_source_id"]]) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
                }
                [self showToast:@"刷新同步成功"];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误" message:@"刷新失败，请检查网络" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
            }
        });
    });
}

- (void)showToast:(NSString *)message {
    UIAlertView *toast = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [toast show];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissWithClickedButtonIndex:0 animated:YES];
    });
}

@end