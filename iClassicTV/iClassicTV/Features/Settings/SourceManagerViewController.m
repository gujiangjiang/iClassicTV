//
//  SourceManagerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "SourceManagerViewController.h"
#import "TextImportModalViewController.h"
#import "AppDataManager.h"
#import "NSString+EncodingHelper.h"
#import "NetworkManager.h" // 引入全局独立的下载模块
#import "ToastHelper.h"
#import "UIViewController+ScrollToTop.h"
#import "AlertHelper.h" // 引入通用弹窗模块
#import "LanguageManager.h" // 新增：引入多语言模块

@interface SourceManagerViewController () <UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) NSArray *scannedLocalFiles;
@end

@implementation SourceManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"source_manager_title");
    
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddOptions)];
    self.navigationItem.rightBarButtonItem = addBtn;
    
    [self enableNavigationBarDoubleTapToScrollTop];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.sources = [[AppDataManager sharedManager] getAllSources];
    [self.tableView reloadData];
}

- (void)showAddOptions {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"add_source") delegate:self cancelButtonTitle:LocalizedString(@"cancel") destructiveButtonTitle:nil otherButtonTitles:LocalizedString(@"add_network_source"), LocalizedString(@"add_local_text_source"), LocalizedString(@"import_from_itunes"), nil];
    sheet.tag = 101;
    [sheet showInView:self.view];
}

#pragma mark - Table View Data Source

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
    
    NSDictionary *activeInfo = [[AppDataManager sharedManager] getActiveSourceInfo];
    if ([source[@"id"] isEqualToString:activeInfo[@"id"]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    if ([source[@"url"] length] > 0) {
        cell.detailTextLabel.text = source[@"url"];
    } else {
        cell.detailTextLabel.text = LocalizedString(@"local_external_source");
    }
    
    return cell;
}

// 开启侧滑删除功能
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// 处理侧滑删除动作
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // 使用公共的 AlertHelper 模块实现侧滑删除确认，多语言支持
        __weak typeof(self) weakSelf = self;
        [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"confirm_delete")
                                       message:LocalizedString(@"confirm_delete_source")
                                  confirmTitle:LocalizedString(@"delete")
                                   cancelTitle:LocalizedString(@"cancel")
                                  confirmBlock:^{
                                      [[AppDataManager sharedManager] deleteSourceAtIndex:indexPath.row];
                                      weakSelf.sources = [[AppDataManager sharedManager] getAllSources];
                                      [tableView reloadData];
                                  } cancelBlock:nil];
    }
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.selectedIndexPath = indexPath;
    NSDictionary *source = self.sources[indexPath.row];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"operation") delegate:self cancelButtonTitle:nil destructiveButtonTitle:LocalizedString(@"delete") otherButtonTitles:LocalizedString(@"set_as_current"), LocalizedString(@"rename"), nil];
    
    if ([source[@"url"] length] > 0) {
        [sheet addButtonWithTitle:LocalizedString(@"refresh_sync")];
    }
    [sheet addButtonWithTitle:LocalizedString(@"cancel")];
    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    
    sheet.tag = 100;
    [sheet showInView:self.view];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    if (actionSheet.tag == 101) {
        if (buttonIndex == 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"network_source") message:LocalizedString(@"enter_m3u_url") delegate:self cancelButtonTitle:LocalizedString(@"cancel") otherButtonTitles:LocalizedString(@"download"), nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            [alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeURL;
            alert.tag = 201;
            [alert show];
        } else if (buttonIndex == 1) {
            TextImportModalViewController *textVC = [[TextImportModalViewController alloc] init];
            textVC.completionHandler = ^(NSString *text) {
                self.tempM3UData = text;
                self.tempURLString = @"";
                [self showNamingAlertWithTag:204 presetName:nil];
            };
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:textVC];
            [self presentViewController:nav animated:YES completion:nil];
        } else if (buttonIndex == 2) {
            NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docsPath error:nil];
            NSMutableArray *m3uFiles = [NSMutableArray array];
            for (NSString *file in files) {
                NSString *ext = [[file lowercaseString] pathExtension];
                if ([ext isEqualToString:@"m3u"] || [ext isEqualToString:@"m3u8"]) {
                    [m3uFiles addObject:file];
                }
            }
            
            if (m3uFiles.count == 0) {
                [ToastHelper showToastWithMessage:LocalizedString(@"no_m3u_found")];
                return;
            }
            
            self.scannedLocalFiles = m3uFiles;
            UIActionSheet *fileSheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"select_shared_file") delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
            for (NSString *file in m3uFiles) {
                [fileSheet addButtonWithTitle:file];
            }
            [fileSheet addButtonWithTitle:LocalizedString(@"cancel")];
            fileSheet.cancelButtonIndex = fileSheet.numberOfButtons - 1;
            fileSheet.tag = 102;
            [fileSheet showInView:self.view];
        }
        return;
    }
    
    if (actionSheet.tag == 102) {
        NSString *fileName = self.scannedLocalFiles[buttonIndex];
        NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [docsPath stringByAppendingPathComponent:fileName];
        
        NSString *content = [NSString stringWithContentsOfFileWithFallback:filePath];
        
        if (content && content.length > 0) {
            self.tempM3UData = content;
            self.tempURLString = @"";
            [self showNamingAlertWithTag:204 presetName:[fileName stringByDeletingPathExtension]];
        } else {
            [ToastHelper showToastWithMessage:LocalizedString(@"read_failed")];
        }
        return;
    }
    
    if (actionSheet.tag == 100) {
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        NSDictionary *sourceDict = self.sources[self.selectedIndexPath.row];
        
        if ([title isEqualToString:LocalizedString(@"delete")]) {
            // 使用公共 AlertHelper，替代原生多余 delegate 处理
            __weak typeof(self) weakSelf = self;
            [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"confirm_delete")
                                           message:LocalizedString(@"confirm_delete_source")
                                      confirmTitle:LocalizedString(@"delete")
                                       cancelTitle:LocalizedString(@"cancel")
                                      confirmBlock:^{
                                          [[AppDataManager sharedManager] deleteSourceAtIndex:weakSelf.selectedIndexPath.row];
                                          weakSelf.sources = [[AppDataManager sharedManager] getAllSources];
                                          [weakSelf.tableView reloadData];
                                      } cancelBlock:nil];
        } else if ([title isEqualToString:LocalizedString(@"set_as_current")]) {
            [[AppDataManager sharedManager] setActiveSourceById:sourceDict[@"id"]];
            [self.tableView reloadData];
            [ToastHelper showToastWithMessage:LocalizedString(@"source_switched")];
        } else if ([title isEqualToString:LocalizedString(@"rename")]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"rename") message:LocalizedString(@"enter_new_name") delegate:self cancelButtonTitle:LocalizedString(@"cancel") otherButtonTitles:LocalizedString(@"confirm"), nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            UITextField *tf = [alert textFieldAtIndex:0];
            tf.text = sourceDict[@"name"];
            alert.tag = 301;
            [alert show];
        } else if ([title isEqualToString:LocalizedString(@"refresh_sync")]) {
            [self refreshSource:sourceDict atIndex:self.selectedIndexPath.row];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) return;
    
    if (alertView.tag == 301) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        if (tf.text.length > 0) {
            [[AppDataManager sharedManager] updateSourceNameAtIndex:self.selectedIndexPath.row withName:tf.text];
            self.sources = [[AppDataManager sharedManager] getAllSources];
            [self.tableView reloadData];
        }
    } else if (alertView.tag == 201) {
        NSString *urlStr = [alertView textFieldAtIndex:0].text;
        NSURL *url = [NSURL URLWithString:urlStr];
        if (!url) {
            [ToastHelper showToastWithMessage:LocalizedString(@"invalid_url")];
            return;
        }
        
        UIAlertView *hud = [[UIAlertView alloc] initWithTitle:LocalizedString(@"downloading") message:LocalizedString(@"please_wait") delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
        [hud show];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *m3uData = [[NetworkManager sharedManager] downloadStringSyncFromURL:url];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud dismissWithClickedButtonIndex:0 animated:YES];
                if (m3uData) {
                    self.tempM3UData = m3uData;
                    self.tempURLString = urlStr;
                    [self showNamingAlertWithTag:203 presetName:nil];
                } else {
                    [ToastHelper showToastWithMessage:LocalizedString(@"download_failed")];
                }
            });
        });
    } else if (alertView.tag == 203 || alertView.tag == 204) {
        NSString *name = [alertView textFieldAtIndex:0].text;
        if (name.length == 0) name = LocalizedString(@"unnamed_source");
        
        [[AppDataManager sharedManager] addSourceWithName:name content:self.tempM3UData url:self.tempURLString];
        [ToastHelper showToastWithMessage:LocalizedString(@"source_saved")];
        
        self.sources = [[AppDataManager sharedManager] getAllSources];
        [self.tableView reloadData];
    }
}

- (void)showNamingAlertWithTag:(NSInteger)tag presetName:(NSString *)presetName {
    UIAlertView *nameAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"save_source") message:LocalizedString(@"name_the_source") delegate:self cancelButtonTitle:LocalizedString(@"cancel") otherButtonTitles:LocalizedString(@"save"), nil];
    nameAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    
    if (presetName && presetName.length > 0) {
        [nameAlert textFieldAtIndex:0].text = presetName;
    } else {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        [nameAlert textFieldAtIndex:0].text = [df stringFromDate:[NSDate date]];
    }
    
    nameAlert.tag = tag;
    [nameAlert show];
}

- (void)refreshSource:(NSDictionary *)source atIndex:(NSInteger)index {
    NSURL *url = [NSURL URLWithString:source[@"url"]];
    if (!url) return;
    
    UIAlertView *hud = [[UIAlertView alloc] initWithTitle:LocalizedString(@"refreshing") message:LocalizedString(@"please_wait") delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [hud show];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *m3uData = [[NetworkManager sharedManager] downloadStringSyncFromURL:url];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismissWithClickedButtonIndex:0 animated:YES];
            if (m3uData) {
                [[AppDataManager sharedManager] updateSourceContentAtIndex:index withContent:m3uData];
                self.sources = [[AppDataManager sharedManager] getAllSources];
                [ToastHelper showToastWithMessage:LocalizedString(@"refresh_success")];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"error") message:LocalizedString(@"refresh_failed") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
                [alert show];
            }
        });
    });
}

@end