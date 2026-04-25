//
//  EPGManagerViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManagerViewController.h"
#import "EPGManager.h"
#import "EPGSourceListViewController.h"

@interface EPGManagerViewController ()
// EPG 全局开关
@property (nonatomic, strong) UISwitch *epgSwitch;
// 自动更新开关
@property (nonatomic, strong) UISwitch *autoUpdateSwitch;
@end

@implementation EPGManagerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"EPG 节目单管理";
    
    // 初始化总开关并绑定数据源
    self.epgSwitch = [[UISwitch alloc] init];
    self.epgSwitch.on = [EPGManager sharedManager].isEPGEnabled;
    [self.epgSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 初始化自动更新开关
    self.autoUpdateSwitch = [[UISwitch alloc] init];
    self.autoUpdateSwitch.on = [EPGManager sharedManager].autoUpdateOnLaunch;
    [self.autoUpdateSwitch addTarget:self action:@selector(autoUpdateSwitchChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Actions

// 处理总开关状态变化，动态隐藏或显示下方设置
- (void)switchChanged:(UISwitch *)sender {
    BOOL isEnabled = sender.isOn;
    [EPGManager sharedManager].isEPGEnabled = isEnabled;
    
    // 修复：当增删 Section 时，必须使用 insertSections 和 deleteSections，否则会导致数据源与 UI 不匹配崩溃
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)];
    
    [self.tableView beginUpdates];
    if (isEnabled) {
        [self.tableView insertSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.tableView deleteSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.tableView endUpdates];
}

// 处理自动更新开关变化
- (void)autoUpdateSwitchChanged:(UISwitch *)sender {
    [EPGManager sharedManager].autoUpdateOnLaunch = sender.isOn;
}

// 执行 EPG 更新逻辑
- (void)fetchEPGData {
    if ([EPGManager sharedManager].epgSourceURL.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误" message:@"请先在接口设置中选择并启用一个 EPG 接口" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
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
    // 优化：如果未开启 EPG 功能，则只显示开关组，隐藏剩余 3 组
    return [EPGManager sharedManager].isEPGEnabled ? 4 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1; // 开关设置
    if (section == 1) return 1; // 接口地址配置
    if (section == 2) return 1; // 自动获取设置
    if (section == 3) return 2; // 操作选项（更新/清理）
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return @"接口设置";
    if (section == 2) return @"获取设置";
    if (section == 3) return @"数据管理";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        // 修复：取消动态显隐判断，始终显示这段文字，彻底解决开关动画导致的 UI 重叠错乱 Bug
        return @"开启后，播放界面将显示近几天的节目单列表。";
    }
    if (section == 2) {
        return @"开启后，如果本地缓存不存在明日的数据，打开软件时会在后台静默获取最新 EPG 节目单。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"EPGManagerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
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
        cell.textLabel.text = @"EPG 源管理";
        // 查找当前激活的源名称，用于在右侧显示
        NSString *activeName = @"未设置";
        for (NSDictionary *source in [EPGManager sharedManager].epgSources) {
            if ([source[@"isActive"] boolValue]) {
                activeName = source[@"name"];
                break;
            }
        }
        cell.detailTextLabel.text = activeName;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"打开软件自动更新";
        cell.accessoryView = self.autoUpdateSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    } else if (indexPath.section == 3) {
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
        // 跳转到多 EPG 列表管理器
        EPGSourceListViewController *listVC = [[EPGSourceListViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:listVC animated:YES];
        
    } else if (indexPath.section == 3) {
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

@end