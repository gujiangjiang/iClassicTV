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
#import "ToastHelper.h"
#import "LanguageManager.h" // 引入多语言

// 修复：在这里补上 <UIActionSheetDelegate> 协议声明
@interface EPGSourceListViewController () <UIActionSheetDelegate>
@property (nonatomic, assign) NSInteger editingIndex;
@end

@implementation EPGSourceListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 应用多语言
    self.title = LocalizedString(@"epg_source_list_title");
    
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonTapped)];
    self.navigationItem.rightBarButtonItem = addItem;
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.tableView addGestureRecognizer:longPress];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)addButtonTapped {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"select_epg_type") delegate:self cancelButtonTitle:LocalizedString(@"cancel") destructiveButtonTitle:nil otherButtonTitles:LocalizedString(@"epg_type_xml"), LocalizedString(@"epg_type_diyp"), LocalizedString(@"epg_type_epginfo"), nil];
    sheet.tag = 100;
    [sheet showInView:self.view];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (indexPath) {
            self.editingIndex = indexPath.row;
            NSArray *sources = [EPGManager sharedManager].epgSources;
            NSDictionary *source = sources[indexPath.row];
            
            if (source[@"linkedM3UId"]) {
                [ToastHelper showToastWithMessage:LocalizedString(@"m3u_builtin_cannot_edit")];
                return;
            }
            
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"modify_epg_type") delegate:self cancelButtonTitle:LocalizedString(@"cancel") destructiveButtonTitle:nil otherButtonTitles:LocalizedString(@"epg_type_xml"), LocalizedString(@"epg_type_diyp"), LocalizedString(@"epg_type_epginfo"), nil];
            sheet.tag = 101;
            [sheet showInView:self.view];
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    NSString *type = @"xml";
    if (buttonIndex == 1) type = @"diyp";
    else if (buttonIndex == 2) type = @"epginfo";
    
    BOOL isEditing = (actionSheet.tag == 101);
    NSDictionary *source = isEditing ? [EPGManager sharedManager].epgSources[self.editingIndex] : nil;
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [AlertHelper showDoubleInputAlertWithTitle:isEditing ? LocalizedString(@"edit_epg") : LocalizedString(@"add_epg")
                                           message:LocalizedString(@"enter_epg_info")
                                   namePlaceholder:LocalizedString(@"epg_name_placeholder")
                                contentPlaceholder:LocalizedString(@"http_placeholder")
                                          nameText:source[@"name"]
                                       contentText:source[@"url"]
                                      keyboardType:UIKeyboardTypeURL
                                      confirmTitle:LocalizedString(@"save")
                                       cancelTitle:LocalizedString(@"cancel")
                                      confirmBlock:^(NSString *name, NSString *content) {
                                          [weakSelf handleSaveEPGWithName:name url:content type:type isEditing:isEditing];
                                      } cancelBlock:nil];
    });
}

- (void)handleSaveEPGWithName:(NSString *)name url:(NSString *)url type:(NSString *)type isEditing:(BOOL)isEditing {
    NSString *nameText = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *urlText = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (urlText.length == 0) {
        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:LocalizedString(@"url_cannot_be_empty") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [errorAlert show];
        return;
    }
    
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
    return LocalizedString(@"epg_source_list_footer");
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
    
    NSString *type = source[@"type"];
    NSString *typeDesc = @"XML";
    if ([type isEqualToString:@"diyp"]) typeDesc = @"DIYP";
    else if ([type isEqualToString:@"epginfo"]) typeDesc = @"EPGInfo";
    
    if (source[@"linkedM3UId"]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ [%@] %@", LocalizedString(@"m3u_builtin_source"), typeDesc, source[@"url"]];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"[%@] %@", typeDesc, source[@"url"]];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    if ([source[@"isActive"] boolValue]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
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
    NSDictionary *source = [EPGManager sharedManager].epgSources[indexPath.row];
    if (source[@"linkedM3UId"]) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[EPGManager sharedManager] removeEPGSourceAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

@end