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
#import "NSString+EncodingHelper.h" // 引入字符串编码处理辅助模块
#import "ToastHelper.h" // 新增：全局引入独立的 Toast 模块，统一交互样式
// 新增：引入滚动处理通用模块
#import "UIViewController+ScrollToTop.h"

@interface SourceManagerViewController () <UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) NSArray *scannedLocalFiles; // 用于临时存储扫描到的 iTunes 共享文件
@end

@implementation SourceManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"我的直播源";
    
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddOptions)];
    self.navigationItem.rightBarButtonItem = addBtn;
    
    // 新增：调用通用模块，为当前导航栏标题栏注册双击回到最上方的功能
    [self enableNavigationBarDoubleTapToScrollTop];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 统一通过 AppDataManager 获取数据
    self.sources = [[AppDataManager sharedManager] getAllSources];
    [self.tableView reloadData];
}

- (void)showAddOptions {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"添加直播源" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"添加网络直播源", @"添加本地文本源", @"从 iTunes 共享导入", nil];
    sheet.tag = 101;
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
        cell.detailTextLabel.text = @"本地/外部导入源";
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
    
    sheet.tag = 100;
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    // 处理添加按钮
    if (actionSheet.tag == 101) {
        if (buttonIndex == 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"网络直播源" message:@"请输入 M3U 网址 (http://...)" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"下载", nil];
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
            // 扫描 iTunes 共享目录中的 M3U 文件
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
                // 优化：统一调用自定义模块的 Toast
                [ToastHelper showToastWithMessage:@"未找到任何 m3u 文件\n请先通过电脑 iTunes 拖入文件"];
                return;
            }
            
            self.scannedLocalFiles = m3uFiles;
            UIActionSheet *fileSheet = [[UIActionSheet alloc] initWithTitle:@"请选择要导入的共享文件" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
            for (NSString *file in m3uFiles) {
                [fileSheet addButtonWithTitle:file];
            }
            [fileSheet addButtonWithTitle:@"取消"];
            fileSheet.cancelButtonIndex = fileSheet.numberOfButtons - 1;
            fileSheet.tag = 102;
            [fileSheet showInView:self.view];
        }
        return;
    }
    
    // 处理从 iTunes 共享文件列表中的点击选择
    if (actionSheet.tag == 102) {
        NSString *fileName = self.scannedLocalFiles[buttonIndex];
        NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [docsPath stringByAppendingPathComponent:fileName];
        
        // 优化：使用独立模块读取文件，自动处理 UTF-8 和 GBK 编码回退
        NSString *content = [NSString stringWithContentsOfFileWithFallback:filePath];
        
        if (content && content.length > 0) {
            self.tempM3UData = content;
            self.tempURLString = @"";
            [self showNamingAlertWithTag:204 presetName:[fileName stringByDeletingPathExtension]];
        } else {
            // 优化：统一调用自定义模块的 Toast
            [ToastHelper showToastWithMessage:@"读取失败，请检查文件格式是否正确"];
        }
        return;
    }
    
    // 处理单元格点击操作 (全部通过 AppDataManager 处理)
    if (actionSheet.tag == 100) {
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        NSDictionary *sourceDict = self.sources[self.selectedIndexPath.row];
        
        if ([title isEqualToString:@"删除"]) {
            [[AppDataManager sharedManager] deleteSourceAtIndex:self.selectedIndexPath.row];
            self.sources = [[AppDataManager sharedManager] getAllSources];
            [self.tableView reloadData];
        } else if ([title isEqualToString:@"设为当前源"]) {
            [[AppDataManager sharedManager] setActiveSourceById:sourceDict[@"id"]];
            [self.tableView reloadData];
            // 优化：统一调用自定义模块的 Toast
            [ToastHelper showToastWithMessage:@"已切换直播源"];
        } else if ([title isEqualToString:@"重命名"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"重命名" message:@"请输入新的名称" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            UITextField *tf = [alert textFieldAtIndex:0];
            tf.text = sourceDict[@"name"];
            alert.tag = 301;
            [alert show];
        } else if ([title isEqualToString:@"刷新同步"]) {
            [self refreshSource:sourceDict atIndex:self.selectedIndexPath.row];
        }
    }
}

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
            // 优化：统一调用自定义模块的 Toast
            [ToastHelper showToastWithMessage:@"网址无效"];
            return;
        }
        
        UIAlertView *hud = [[UIAlertView alloc] initWithTitle:@"下载中..." message:@"请稍候\n\n" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
        [hud show];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 优化：使用独立模块下载文件，自动处理 UTF-8 和 GBK 编码回退
            NSString *m3uData = [NSString stringWithContentsOfURLWithFallback:url];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [hud dismissWithClickedButtonIndex:0 animated:YES];
                if (m3uData) {
                    self.tempM3UData = m3uData;
                    self.tempURLString = urlStr;
                    [self showNamingAlertWithTag:203 presetName:nil];
                } else {
                    // 优化：统一调用自定义模块的 Toast
                    [ToastHelper showToastWithMessage:@"下载失败，请检查网络"];
                }
            });
        });
    } else if (alertView.tag == 203 || alertView.tag == 204) {
        NSString *name = [alertView textFieldAtIndex:0].text;
        if (name.length == 0) name = @"未命名直播源";
        
        // 统一调用 AppDataManager 新增源
        [[AppDataManager sharedManager] addSourceWithName:name content:self.tempM3UData url:self.tempURLString];
        // 优化：统一调用自定义模块的 Toast
        [ToastHelper showToastWithMessage:@"直播源已成功保存！"];
        
        self.sources = [[AppDataManager sharedManager] getAllSources];
        [self.tableView reloadData];
    }
}

- (void)showNamingAlertWithTag:(NSInteger)tag presetName:(NSString *)presetName {
    UIAlertView *nameAlert = [[UIAlertView alloc] initWithTitle:@"保存直播源" message:@"请为该直播源命名" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
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
    
    UIAlertView *hud = [[UIAlertView alloc] initWithTitle:@"刷新中..." message:@"请稍候\n\n" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [hud show];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 优化：使用独立模块下载文件，自动处理 UTF-8 和 GBK 编码回退
        NSString *m3uData = [NSString stringWithContentsOfURLWithFallback:url];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismissWithClickedButtonIndex:0 animated:YES];
            if (m3uData) {
                [[AppDataManager sharedManager] updateSourceContentAtIndex:index withContent:m3uData];
                self.sources = [[AppDataManager sharedManager] getAllSources];
                // 优化：统一调用自定义模块的 Toast
                [ToastHelper showToastWithMessage:@"刷新同步成功"];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误" message:@"刷新失败，请检查网络" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
            }
        });
    });
}

@end