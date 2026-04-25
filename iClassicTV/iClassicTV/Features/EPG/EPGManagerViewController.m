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
#import "LanguageManager.h"

#pragma mark - 内部新增类：EPG 时区选择控制器
// -------------------------------------------------------------
@interface EPGTimeZoneListViewController : UITableViewController
@property (nonatomic, strong) NSArray *timeZones;
@property (nonatomic, copy) NSString *selectedTimeZoneName;
@end

@implementation EPGTimeZoneListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"EPG 时区";
    
    // 生成从 GMT-12 到 GMT+14 的时区列表，把跟随系统默认放在首位
    NSMutableArray *arr = [NSMutableArray array];
    [arr addObject:@"System"];
    for (NSInteger i = -12; i <= 14; i++) {
        NSString *sign = i >= 0 ? @"+" : @"-";
        NSString *tzName = [NSString stringWithFormat:@"GMT%@%02ld00", sign, (long)ABS(i)];
        [arr addObject:tzName];
    }
    self.timeZones = [arr copy];
    
    self.selectedTimeZoneName = [[NSUserDefaults standardUserDefaults] stringForKey:@"ios6_iptv_epg_timezone_name"];
    if (self.selectedTimeZoneName.length == 0) {
        self.selectedTimeZoneName = @"System";
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSUInteger index = [self.timeZones indexOfObject:self.selectedTimeZoneName];
    if (index != NSNotFound) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.timeZones.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"TZCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    
    NSString *tz = self.timeZones[indexPath.row];
    if ([tz isEqualToString:@"System"]) {
        cell.textLabel.text = @"跟随设备默认时区";
    } else {
        if ([tz hasPrefix:@"GMT"] && tz.length == 8) {
            NSString *sign = [tz substringWithRange:NSMakeRange(3, 1)];
            NSString *hour = [tz substringWithRange:NSMakeRange(4, 2)];
            NSString *min = [tz substringWithRange:NSMakeRange(6, 2)];
            cell.textLabel.text = [NSString stringWithFormat:@"GMT%@%@:%@", sign, hour, min];
        } else {
            cell.textLabel.text = tz;
        }
    }
    
    if ([tz isEqualToString:self.selectedTimeZoneName]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *tz = self.timeZones[indexPath.row];
    self.selectedTimeZoneName = tz;
    
    if ([tz isEqualToString:@"System"]) {
        [EPGManager sharedManager].epgTimeZone = nil;
    } else {
        [EPGManager sharedManager].epgTimeZone = [NSTimeZone timeZoneWithName:tz];
    }
    
    [self.tableView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
// -------------------------------------------------------------


#pragma mark - EPGManagerViewController 主类实现

@interface EPGManagerViewController ()
@property (nonatomic, strong) UISwitch *epgSwitch;
@property (nonatomic, strong) UISwitch *autoUpdateSwitch;
@end

@implementation EPGManagerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = LocalizedString(@"epg_manager_title");
    
    // 修复：为 EPGManager 设置属于自己的 backBarButtonItem
    // 这样当它 Push 出 EPG接口列表 时，左上角显示的就会是多语言的“返回”
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"back") style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.navigationItem.backBarButtonItem = backItem;
    
    if (self.navigationController.viewControllers.firstObject == self) {
        UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"close") style:UIBarButtonItemStyleBordered target:self action:@selector(closeSettings)];
        self.navigationItem.leftBarButtonItem = closeItem;
    }
    
    self.epgSwitch = [[UISwitch alloc] init];
    self.epgSwitch.on = [EPGManager sharedManager].isEPGEnabled;
    [self.epgSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.autoUpdateSwitch = [[UISwitch alloc] init];
    self.autoUpdateSwitch.on = [EPGManager sharedManager].autoUpdateOnLaunch;
    [self.autoUpdateSwitch addTarget:self action:@selector(autoUpdateSwitchChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)switchChanged:(UISwitch *)sender {
    BOOL isEnabled = sender.isOn;
    [EPGManager sharedManager].isEPGEnabled = isEnabled;
    
    // 优化：修改动态插入的 section 数量，以适配新增的时区选项
    BOOL isDynamic = [EPGManager sharedManager].isDynamicEPGSource;
    NSInteger sectionsCount = isDynamic ? 2 : 4;
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, sectionsCount)];
    
    [self.tableView beginUpdates];
    if (isEnabled) {
        [self.tableView insertSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.tableView deleteSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.tableView endUpdates];
}

- (void)autoUpdateSwitchChanged:(UISwitch *)sender {
    [EPGManager sharedManager].autoUpdateOnLaunch = sender.isOn;
}

- (void)fetchEPGData {
    if ([EPGManager sharedManager].epgSourceURL.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"error") message:LocalizedString(@"epg_please_select_source") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    UIAlertView *loadingAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"epg_updating_title") message:LocalizedString(@"please_wait") delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicator.center = CGPointMake(142.0f, 80.0f);
    [indicator startAnimating];
    [loadingAlert addSubview:indicator];
    [loadingAlert show];
    
    [[EPGManager sharedManager] fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        [loadingAlert dismissWithClickedButtonIndex:0 animated:YES];
        
        NSString *msg = success ? LocalizedString(@"epg_update_success_alert") : [NSString stringWithFormat:LocalizedString(@"epg_update_failed_format"), errorMsg];
        UIAlertView *resultAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:msg delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [resultAlert show];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // 优化：返回对应的 section 数（增加了一个时区选项 section）
    return [EPGManager sharedManager].isEPGEnabled ? 5 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 1;
    if (section == 2) return 1; // 新增的时区选项
    if (section == 3) return 1; // 原自动更新设置
    if (section == 4) return 2; // 原数据管理
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return LocalizedString(@"epg_source_settings");
    if (section == 2) return @"EPG 时区设置"; // 使用默认中文标识
    if (section == 3) return LocalizedString(@"epg_fetch_settings");
    if (section == 4) return LocalizedString(@"data_management");
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return LocalizedString(@"epg_switch_footer");
    // 新增：针对时区设置添加详细解释说明
    if (section == 2) return @"默认跟随设备所在时区。如果您的直播源节目单对应其他时区（如中国源通常为东八区），可手动指定以确保时间匹配。";
    if (section == 3) return LocalizedString(@"epg_auto_update_footer");
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"EPGManagerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.text = @"";
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    if (indexPath.section == 0) {
        cell.textLabel.text = LocalizedString(@"enable_epg");
        cell.accessoryView = self.epgSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    } else if (indexPath.section == 1) {
        cell.textLabel.text = LocalizedString(@"epg_source_management");
        NSString *activeName = LocalizedString(@"not_set");
        for (NSDictionary *source in [EPGManager sharedManager].epgSources) {
            if ([source[@"isActive"] boolValue]) {
                activeName = source[@"name"];
                break;
            }
        }
        cell.detailTextLabel.text = activeName;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else if (indexPath.section == 2) {
        // 新增：时区展示和格式化
        cell.textLabel.text = @"EPG 时区";
        NSString *tzName = [[NSUserDefaults standardUserDefaults] stringForKey:@"ios6_iptv_epg_timezone_name"];
        if (!tzName || tzName.length == 0 || [tzName isEqualToString:@"System"]) {
            cell.detailTextLabel.text = @"跟随设备默认";
        } else {
            if ([tzName hasPrefix:@"GMT"] && tzName.length == 8) {
                NSString *sign = [tzName substringWithRange:NSMakeRange(3, 1)];
                NSString *hour = [tzName substringWithRange:NSMakeRange(4, 2)];
                NSString *min = [tzName substringWithRange:NSMakeRange(6, 2)];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"GMT%@%@:%@", sign, hour, min];
            } else {
                cell.detailTextLabel.text = tzName;
            }
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else if (indexPath.section == 3) {
        cell.textLabel.text = LocalizedString(@"auto_update_on_launch");
        cell.accessoryView = self.autoUpdateSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    } else if (indexPath.section == 4) {
        if (indexPath.row == 0) {
            cell.textLabel.text = LocalizedString(@"force_update_epg");
        } else {
            cell.textLabel.text = LocalizedString(@"clear_epg_cache");
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        EPGSourceListViewController *listVC = [[EPGSourceListViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:listVC animated:YES];
    } else if (indexPath.section == 2) {
        // 新增：点击跳转到时区选择列表页面
        EPGTimeZoneListViewController *tzVC = [[EPGTimeZoneListViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:tzVC animated:YES];
    } else if (indexPath.section == 4) {
        if (indexPath.row == 0) {
            [self fetchEPGData];
        } else if (indexPath.row == 1) {
            [[EPGManager sharedManager] clearEPGCache];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:LocalizedString(@"epg_cache_cleared") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
            [alert show];
        }
    }
}

@end