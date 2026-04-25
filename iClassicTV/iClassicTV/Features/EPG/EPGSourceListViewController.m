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

@property (nonatomic, strong) NSString *tempAddName;
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
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"添加 EPG" message:@"请输入 EPG 接口名称" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"下一步", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *textField = [alert textFieldAtIndex:0];
    textField.placeholder = @"例如：默认EPG源";
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
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"修改 EPG 名称" message:@"请输入新的名称" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"修改链接", nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            UITextField *textField = [alert textFieldAtIndex:0];
            textField.text = source[@"name"];
            alert.tag = 200;
            [alert show];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) return; // 取消
    
    UITextField *textField = [alertView textFieldAtIndex:0];
    NSString *inputText = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (alertView.tag == 100) {
        // 添加 - 输入名称完毕，要求输入链接
        self.tempAddName = inputText.length > 0 ? inputText : @"自定义 EPG";
        UIAlertView *urlAlert = [[UIAlertView alloc] initWithTitle:@"添加 EPG" message:@"请输入 EPG 接口链接" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
        urlAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *urlField = [urlAlert textFieldAtIndex:0];
        urlField.placeholder = @"http://...";
        urlAlert.tag = 101;
        [urlAlert show];
        
    } else if (alertView.tag == 101) {
        // 添加 - 输入链接完毕，保存
        if (inputText.length > 0) {
            [[EPGManager sharedManager] addEPGSourceWithName:self.tempAddName url:inputText];
            [self.tableView reloadData];
        }
        
    } else if (alertView.tag == 200) {
        // 编辑 - 修改名称完毕，要求修改链接
        NSString *newName = inputText.length > 0 ? inputText : @"自定义 EPG";
        NSDictionary *source = [EPGManager sharedManager].epgSources[self.editingIndex];
        self.tempAddName = newName;
        
        UIAlertView *urlAlert = [[UIAlertView alloc] initWithTitle:@"修改 EPG 链接" message:@"请输入新的接口链接" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存", nil];
        urlAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *urlField = [urlAlert textFieldAtIndex:0];
        urlField.text = source[@"url"];
        urlAlert.tag = 201;
        [urlAlert show];
        
    } else if (alertView.tag == 201) {
        // 编辑 - 修改链接完毕，保存
        if (inputText.length > 0) {
            [[EPGManager sharedManager] renameEPGSourceAtIndex:self.editingIndex withName:self.tempAddName url:inputText];
            [self.tableView reloadData];
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