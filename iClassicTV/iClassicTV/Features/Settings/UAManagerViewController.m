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

@interface UAManagerViewController () <UIAlertViewDelegate>

@end

@implementation UAManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 优化：使用了合并后的 ua_settings 键
    self.title = LocalizedString(@"ua_settings");
    
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addUATapped)];
    self.navigationItem.rightBarButtonItem = addBtn;
}

- (void)addUATapped {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"add_custom_ua")
                                                    message:nil
                                                   delegate:self
                                          cancelButtonTitle:LocalizedString(@"cancel")
                                          otherButtonTitles:LocalizedString(@"save"), nil];
    alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    alert.tag = 100;
    
    UITextField *nameField = [alert textFieldAtIndex:0];
    nameField.placeholder = LocalizedString(@"ua_name_placeholder");
    
    UITextField *uaField = [alert textFieldAtIndex:1];
    uaField.placeholder = LocalizedString(@"ua_string_placeholder");
    uaField.secureTextEntry = NO;
    
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 100) {
        if (buttonIndex == 1) {
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

// 新增：为左滑删除按钮提供多语言支持
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return LocalizedString(@"delete");
}

@end