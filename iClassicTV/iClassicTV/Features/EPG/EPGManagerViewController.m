//
//  EPGManagerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManagerViewController.h"
#import "EPGManager.h"

@interface EPGManagerViewController () <UIAlertViewDelegate>
// EPG 全局开关
@property (nonatomic, strong) UISwitch *epgSwitch;
@end

@implementation EPGManagerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"EPG 节目单管理";
    
    // 初始化开关并绑定数据源
    self.epgSwitch = [[UISwitch alloc] init];
    self.epgSwitch.on = [EPGManager sharedManager].isEPGEnabled;
    [self.epgSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Actions

// 处理开关状态变化
- (void)switchChanged:(UISwitch *)sender {
    [EPGManager sharedManager].isEPGEnabled = sender.isOn;
}

// 执行 EPG 更新逻辑
- (void)fetchEPGData {
    if ([EPGManager sharedManager].epgSourceURL.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误" message:@"请先设置 EPG 接口地址" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // 兼容 iOS 6 的 Alert 加载动画方案
    UIAlertView *loadingAlert = [[UIAlertView alloc] initWithTitle:@"正在更新 EPG" message:@"请稍候...\n\n" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicator.center = CGPointMake(142.0f, 80.0f);
    [indicator startAnimating];
    [loadingAlert addSubview:indicator];
    [loadingAlert show];
    
    // 异步拉取解析数据
    [[EPGManager sharedManager] fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        [loadingAlert dismissWithClickedButtonIndex:0 animated:YES];
        
        NSString *msg = success ? @"EPG 数据更新成功！" : [NSString stringWithFormat:@"更新失败：%@", errorMsg];
        UIAlertView *resultAlert = [[UIAlertView alloc] initWithTitle:@"提示" message:msg delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [resultAlert show];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1; // 开关设置
    if (section == 1) return 1; // 接口地址配置
    if (section == 2) return 2; // 操作选项（更新/清理）
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return @"接口设置";
    if (section == 2) return @"数据管理";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"开启后，播放界面将显示近几天的节目单列表。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"EPGManagerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // 初始化默认状态
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.text = @"";
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"启用 EPG 功能";
        cell.accessoryView = self.epgSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @"EPG 接口地址";
        NSString *url = [EPGManager sharedManager].epgSourceURL;
        cell.detailTextLabel.text = url.length > 0 ? url : @"未设置";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"立即更新 EPG 数据";
        } else {
            cell.textLabel.text = @"清理 EPG 缓存";
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        // 弹出输入框修改 EPG 接口 URL
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"EPG 接口地址"
                                                        message:@"请输入 XMLTV 格式的 EPG 接口链接"
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                              otherButtonTitles:@"保存", nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *textField = [alert textFieldAtIndex:0];
        textField.text = [EPGManager sharedManager].epgSourceURL;
        textField.placeholder = @"http://...";
        alert.tag = 101;
        [alert show];
        
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            // 执行网络更新
            [self fetchEPGData];
        } else if (indexPath.row == 1) {
            // 清除本地缓存
            [[EPGManager sharedManager] clearEPGCache];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"EPG 缓存已清理" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alert show];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 101 && buttonIndex == 1) { // 点击了保存按钮
        UITextField *textField = [alertView textFieldAtIndex:0];
        NSString *newURL = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [EPGManager sharedManager].epgSourceURL = newURL;
        [self.tableView reloadData];
    }
}

@end