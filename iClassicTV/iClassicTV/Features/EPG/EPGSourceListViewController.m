//
//  EPGSourceListViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGSourceListViewController.h"
#import "EPGManager.h"
#import "AlertHelper.h"

// 新增：引入 UIActionSheetDelegate 以选择接口类型
@interface EPGSourceListViewController () <UIActionSheetDelegate>

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
    // 优化：先让用户选择添加的 EPG 接口类型
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"选择接口类型" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"XML 压缩包 (全局下载)", @"DIYP 接口 (按需动态)", @"EPGInfo 接口 (按需动态)", nil];
    sheet.tag = 100;
    [sheet showInView:self.view];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (indexPath) {
            self.editingIndex = indexPath.row;
            // 优化：编辑时同样也支持选择接口类型
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"修改接口类型" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"XML 压缩包 (全局下载)", @"DIYP 接口 (按需动态)", @"EPGInfo 接口 (按需动态)", nil];
            sheet.tag = 101;
            [sheet showInView:self.view];
        }
    }
}

#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    NSString *type = @"xml";
    if (buttonIndex == 1) type = @"diyp";
    else if (buttonIndex == 2) type = @"epginfo";
    
    BOOL isEditing = (actionSheet.tag == 101);
    NSDictionary *source = isEditing ? [EPGManager sharedManager].epgSources[self.editingIndex] : nil;
    
    __weak typeof(self) weakSelf = self;
    
    // 延迟弹出 Alert 保证界面流转顺滑
    dispatch_async(dispatch_get_main_queue(), ^{
        [AlertHelper showDoubleInputAlertWithTitle:isEditing ? @"修改 EPG" : @"添加 EPG"
                                           message:@"请输入 EPG 接口名称和链接"
                                   namePlaceholder:@"名称 (留空默认为当前时间)"
                                contentPlaceholder:@"http://..."
                                          nameText:source[@"name"]
                                       contentText:source[@"url"]
                                      keyboardType:UIKeyboardTypeURL
                                      confirmTitle:@"保存"
                                       cancelTitle:@"取消"
                                      confirmBlock:^(NSString *name, NSString *content) {
                                          [weakSelf handleSaveEPGWithName:name url:content type:type isEditing:isEditing];
                                      } cancelBlock:nil];
    });
}

// 统一的 EPG 保存/更新处理逻辑
- (void)handleSaveEPGWithName:(NSString *)name url:(NSString *)url type:(NSString *)type isEditing:(BOOL)isEditing {
    NSString *nameText = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *urlText = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (urlText.length == 0) {
        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"接口链接不能为空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [errorAlert show];
        return;
    }
    
    // 若名称留空，按要求默认设置为当前时间
    if (nameText.length == 0) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        nameText = [df stringFromDate:[NSDate date]];
    }
    
    if (isEditing) {
        [[EPGManager sharedManager] renameEPGSourceAtIndex:self.editingIndex withName:nameText url:urlText type:type];
    } else {
        [[EPGManager sharedManager] addEPGSourceWithName:nameText url:urlText type:type];
    }
    
    [self.tableView reloadData];
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
    
    // 优化：右下角直接标识出源的类型，方便用户区分
    NSString *type = source[@"type"];
    NSString *typeDesc = @"XML";
    if ([type isEqualToString:@"diyp"]) typeDesc = @"DIYP";
    else if ([type isEqualToString:@"epginfo"]) typeDesc = @"EPGInfo";
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"[%@] %@", typeDesc, source[@"url"]];
    
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