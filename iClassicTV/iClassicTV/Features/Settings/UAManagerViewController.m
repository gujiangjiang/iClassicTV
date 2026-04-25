//
//  UAManagerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UAManagerViewController.h"
#import "UserAgentManager.h"
#import "AlertHelper.h"
#import "LanguageManager.h"
#import "ToastHelper.h"

@interface UAManagerViewController ()

@end

@implementation UAManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"ua_settings");
    
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addUATapped)];
    self.navigationItem.rightBarButtonItem = addBtn;
}

- (void)addUATapped {
    // 优化：调用封装好的统一双输入框弹窗
    __weak typeof(self) weakSelf = self;
    [AlertHelper showDoubleInputAlertWithTitle:LocalizedString(@"add_custom_ua")
                                       message:nil
                               namePlaceholder:LocalizedString(@"ua_name_placeholder")
                            contentPlaceholder:LocalizedString(@"ua_string_placeholder")
                                      nameText:nil
                                   contentText:nil
                                  keyboardType:UIKeyboardTypeDefault
                                  confirmTitle:LocalizedString(@"save")
                                   cancelTitle:LocalizedString(@"cancel")
                                  confirmBlock:^(NSString *name, NSString *content) {
                                      
                                      NSString *trimmedName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                      NSString *trimmedUA = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                      
                                      // 优化：根据需求，UA 备注名称强制必填，不允许为空
                                      if (trimmedName.length == 0) {
                                          UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:@"备注名不能为空，请重新添加！" delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
                                          [errorAlert show];
                                          return;
                                      }
                                      
                                      if (trimmedUA.length == 0) {
                                          // 此处保持之前的行为逻辑：如果UA内容为空，阻止存入
                                          return;
                                      }
                                      
                                      [[UserAgentManager sharedManager] addUAWithName:trimmedName uaString:trimmedUA];
                                      [weakSelf.tableView reloadData];
                                      
                                  } cancelBlock:nil];
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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    NSArray *uaList = [[UserAgentManager sharedManager] allUAs];
    NSDictionary *uaDict = uaList[indexPath.row];
    
    cell.textLabel.text = uaDict[@"name"];
    cell.detailTextLabel.text = uaDict[@"ua"];
    
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
    
    [[UserAgentManager sharedManager] selectUAAtIndex:indexPath.row];
    
    [self.tableView reloadData];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        __weak typeof(self) weakSelf = self;
        [AlertHelper showConfirmAlertWithTitle:LocalizedString(@"confirm_delete")
                                       message:LocalizedString(@"confirm_delete_ua")
                                  confirmTitle:LocalizedString(@"delete")
                                   cancelTitle:LocalizedString(@"cancel")
                                  confirmBlock:^{
                                      BOOL success = [[UserAgentManager sharedManager] deleteUAAtIndex:indexPath.row];
                                      if (success) {
                                          [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                                          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                              [weakSelf.tableView reloadData];
                                          });
                                      }
                                  } cancelBlock:nil];
    }
}

// 为左滑删除按钮提供多语言支持
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return LocalizedString(@"delete");
}

@end