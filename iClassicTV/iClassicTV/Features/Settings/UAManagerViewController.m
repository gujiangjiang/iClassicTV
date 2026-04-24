//
//  UAManagerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UAManagerViewController.h"
#import "UserAgentManager.h"

@interface UAManagerViewController () <UIAlertViewDelegate>

@end

@implementation UAManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"User-Agent 设置";
    
    // 右上角添加新增按钮
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addUATapped)];
    self.navigationItem.rightBarButtonItem = addBtn;
}

- (void)addUATapped {
    // 兼容 iOS 6/7 的弹窗输入方式：借用登录密码框样式，并强行将密码框改为明文显示
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"添加自定义 User-Agent"
                                                    message:nil
                                                   delegate:self
                                          cancelButtonTitle:@"取消"
                                          otherButtonTitles:@"保存", nil];
    alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    
    UITextField *nameField = [alert textFieldAtIndex:0];
    nameField.placeholder = @"标识名称 (例如: PC 浏览器)";
    
    UITextField *uaField = [alert textFieldAtIndex:1];
    uaField.placeholder = @"完整的 User-Agent 字符串";
    uaField.secureTextEntry = NO; // 取消密码的星号遮挡，作为普通输入框使用
    
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // 点击了保存
        UITextField *nameField = [alertView textFieldAtIndex:0];
        UITextField *uaField = [alertView textFieldAtIndex:1];
        
        NSString *name = [nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *ua = [uaField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (name.length > 0 && ua.length > 0) {
            [[UserAgentManager sharedManager] addUAWithName:name uaString:ua];
            [self.tableView reloadData];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[UserAgentManager sharedManager] allUAs] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"UACell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        // 使用 Subtitle 样式，上面显示名称，下面显示 UA 具体内容
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    NSArray *uaList = [[UserAgentManager sharedManager] allUAs];
    NSDictionary *uaDict = uaList[indexPath.row];
    
    cell.textLabel.text = uaDict[@"name"];
    cell.detailTextLabel.text = uaDict[@"ua"];
    
    // 标记当前正在使用哪一个
    if (indexPath.row == [[UserAgentManager sharedManager] currentSelectedIndex]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 选中启用该项
    [[UserAgentManager sharedManager] selectUAAtIndex:indexPath.row];
    
    // 刷新列表更新打钩状态
    [self.tableView reloadData];
}

// 开启侧滑删除功能
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // 索引 0 是默认项，永远不允许侧滑删除
    if (indexPath.row == 0) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // 删除数据并在界面上移除该行
        BOOL success = [[UserAgentManager sharedManager] deleteUAAtIndex:indexPath.row];
        if (success) {
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            // 延时刷新一下全局状态，防止当前使用的项被删除后打钩状态没及时更新回默认项
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

@end