//
//  EPGSourceListViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGSourceListViewController.h"
#import "EPGManager.h"

@interface EPGSourceListViewController () <UIAlertViewDelegate>

@property (nonatomic, assign) NSInteger editingIndex;

@end

@implementation EPGSourceListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"EPG 接口列表";
    
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonTapped)];
    self.navigationItem.rightBarButtonItem = addItem;
    
    // 添加长按手势用于重命名/编辑
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:longPress];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)addButtonTapped {
    // 优化：使用 LoginAndPasswordInput 样式来实现两个输入框同屏显示
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"添加 EPG" message:@"请输入 EPG 接口名称和链接" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
    alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    
    UITextField *nameField = [alert textFieldAtIndex:0];
    nameField.placeholder = @"名称 (例如：默认EPG源)";
    
    UITextField *urlField = [alert textFieldAtIndex:1];
    // 关键优化：取消密码输入框的圆点遮挡，使其变成普通的明文输入框
    urlField.secureTextEntry = NO;
    urlField.placeholder = @"http://...";
    urlField.keyboardType = UIKeyboardTypeURL;
    
    alert.tag = 100;
    [alert show];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (indexPath) {
            self.editingIndex = indexPath.row;
            NSArray *sources = [EPGManager sharedManager].epgSources;
            NSDictionary *source = sources[indexPath.row];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"修改 EPG" message:@"请输入新的名称和链接" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
            alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
            
            UITextField *nameField = [alert textFieldAtIndex:0];
            nameField.text = source[@"name"];
            nameField.placeholder = @"名称";
            
            UITextField *urlField = [alert textFieldAtIndex:1];
            // 关键优化：取消密码输入框的圆点遮挡，使其变成普通的明文输入框
            urlField.secureTextEntry = NO;
            urlField.text = source[@"url"];
            urlField.placeholder = @"http://...";
            urlField.keyboardType = UIKeyboardTypeURL;
            
            alert.tag = 200;
            [alert show];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) return; // 取消
    
    // 一次性获取两个输入框的内容
    UITextField *nameField = [alertView textFieldAtIndex:0];
    UITextField *urlField = [alertView textFieldAtIndex:1];
    
    NSString *nameText = [nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *urlText = [urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 提供默认名称
    if (nameText.length == 0) {
        nameText = @"自定义 EPG";
    }
    
    if (alertView.tag == 100) {
        // 添加
        if (urlText.length > 0) {
            [[EPGManager sharedManager] addEPGSourceWithName:nameText url:urlText];
            [self.tableView reloadData];
        } else {
            UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"接口链接不能为空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [errorAlert show];
        }
    } else if (alertView.tag == 200) {
        // 编辑
        if (urlText.length > 0) {
            [[EPGManager sharedManager] renameEPGSourceAtIndex:self.editingIndex withName:nameText url:urlText];
            [self.tableView reloadData];
        } else {
            UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"接口链接不能为空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [errorAlert show];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [EPGManager sharedManager].epgSources.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"提示：点击选中并启用 EPG，长按可修改名称和链接，左滑可删除。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"EPGSourceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSArray *sources = [EPGManager sharedManager].epgSources;
    NSDictionary *source = sources[indexPath.row];
    
    cell.textLabel.text = source[@"name"];
    cell.detailTextLabel.text = source[@"url"];
    
    // 高亮当前选中的源
    if ([source[@"isActive"] boolValue]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0]; // iOS系统蓝
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[EPGManager sharedManager] setActiveEPGSourceAtIndex:indexPath.row];
    [self.tableView reloadData];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES; // 允许滑动删除
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[EPGManager sharedManager] removeEPGSourceAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        // 延迟刷新以更新可能变更的 Checkmark
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

@end