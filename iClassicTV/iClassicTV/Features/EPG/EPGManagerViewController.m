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
    self.title = LocalizedString(@"epg_timezone");
    
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
        cell.textLabel.text = LocalizedString(@"epg_timezone_system_default");
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

#pragma mark - 内部新增类：EPG 自动回正时间选择控制器
// -------------------------------------------------------------
@interface EPGAutoScrollListViewController : UITableViewController
@property (nonatomic, strong) NSArray *options;
@property (nonatomic, strong) NSArray *titles;
@end

@implementation EPGAutoScrollListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"epg_auto_scroll");
    self.options = @[@0, @5, @10, @15, @30];
    // 动态生成带有多语言格式的标题列表
    self.titles = @[
                    LocalizedString(@"epg_auto_scroll_none"),
                    [NSString stringWithFormat:LocalizedString(@"epg_seconds_format"), (long)5],
                    [NSString stringWithFormat:LocalizedString(@"epg_seconds_format"), (long)10],
                    [NSString stringWithFormat:LocalizedString(@"epg_seconds_format"), (long)15],
                    [NSString stringWithFormat:LocalizedString(@"epg_seconds_format"), (long)30]
                    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.options.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"AutoScrollCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    
    cell.textLabel.text = self.titles[indexPath.row];
    
    NSInteger currentTimeout = [EPGManager sharedManager].autoScrollTimeout;
    if (currentTimeout == [self.options[indexPath.row] integerValue]) {
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
    [EPGManager sharedManager].autoScrollTimeout = [self.options[indexPath.row] integerValue];
    [self.tableView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
// -------------------------------------------------------------

#pragma mark - 内部类：EPG 定时刷新时间选择控制器
// -------------------------------------------------------------
@interface EPGScheduledTimeViewController : UIViewController
@property (nonatomic, strong) UIDatePicker *datePicker;
@end

@implementation EPGScheduledTimeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"scheduled_update_time");
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.frame = CGRectMake(0, 20, self.view.bounds.size.width, 216);
    self.datePicker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.datePicker.datePickerMode = UIDatePickerModeTime;
    [self.view addSubview:self.datePicker];
    
    NSString *timeStr = [EPGManager sharedManager].scheduledUpdateTimeString;
    if (timeStr.length > 0) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"HH:mm"];
        NSDate *date = [df dateFromString:timeStr];
        if (date) {
            [self.datePicker setDate:date animated:NO];
        }
    }
    
    UIBarButtonItem *saveItem = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"save") style:UIBarButtonItemStyleDone target:self action:@selector(saveAction)];
    self.navigationItem.rightBarButtonItem = saveItem;
    
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    clearBtn.frame = CGRectMake(20, CGRectGetMaxY(self.datePicker.frame) + 30, self.view.bounds.size.width - 40, 44);
    [clearBtn setTitle:LocalizedString(@"disable_scheduled_update") forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearBtn];
}

- (void)saveAction {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm"];
    NSString *str = [df stringFromDate:self.datePicker.date];
    [EPGManager sharedManager].scheduledUpdateTimeString = str;
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)clearAction {
    [EPGManager sharedManager].scheduledUpdateTimeString = @"";
    [self.navigationController popViewControllerAnimated:YES];
}

@end
// -------------------------------------------------------------

#pragma mark - EPGManagerViewController 主类实现

@interface EPGManagerViewController ()
@property (nonatomic, strong) UISwitch *epgSwitch;
@property (nonatomic, strong) UISwitch *autoUpdateSwitch;
@property (nonatomic, strong) UISwitch *autoExpireSwitch;
@end

@implementation EPGManagerViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = LocalizedString(@"epg_manager_title");
    
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
    
    self.autoExpireSwitch = [[UISwitch alloc] init];
    self.autoExpireSwitch.on = [EPGManager sharedManager].autoUpdateOnExpire;
    [self.autoExpireSwitch addTarget:self action:@selector(autoExpireSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // [修改] 仅保留数据解析完毕用于刷新 tableView 的监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(epgDataDidUpdate) name:@"EPGDataDidUpdateNotification" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 数据更新后的通知回调
- (void)epgDataDidUpdate {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
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

- (void)autoExpireSwitchChanged:(UISwitch *)sender {
    [EPGManager sharedManager].autoUpdateOnExpire = sender.isOn;
}

- (void)fetchEPGData {
    if ([EPGManager sharedManager].epgSourceURL.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"error") message:LocalizedString(@"epg_please_select_source") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // [优化] 由于已启用 ToastHelper 全局悬浮窗进度条机制，这里直接调用数据方法，UI 层面完全不阻塞
    [[EPGManager sharedManager] fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                NSString *msg = [NSString stringWithFormat:LocalizedString(@"epg_update_failed_format"), errorMsg ?: LocalizedString(@"unknown_error")];
                UIAlertView *resultAlert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:msg delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
                [resultAlert show];
            } else {
                [self.tableView reloadData];
            }
        });
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (![EPGManager sharedManager].isEPGEnabled) {
        return 1;
    }
    return [EPGManager sharedManager].isDynamicEPGSource ? 3 : 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 1;
    if (section == 2) return 2;
    if (section == 3) return 3;
    if (section == 4) return 2;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return LocalizedString(@"epg_source_settings");
    if (section == 2) return LocalizedString(@"epg_ui_and_timezone_settings");
    if (section == 3) return LocalizedString(@"epg_fetch_settings");
    if (section == 4) return LocalizedString(@"data_management");
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return LocalizedString(@"epg_switch_footer");
    if (section == 2) return LocalizedString(@"epg_ui_and_timezone_footer");
    if (section == 3) return LocalizedString(@"epg_auto_update_footer");
    if (section == 4) {
        NSDate *lastTime = [EPGManager sharedManager].lastEPGUpdateTime;
        if (lastTime) {
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            return [NSString stringWithFormat:@"%@: %@", LocalizedString(@"last_update_time_label"), [df stringFromDate:lastTime]];
        } else {
            return LocalizedString(@"no_update_record");
        }
    }
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
        if (indexPath.row == 0) {
            cell.textLabel.text = LocalizedString(@"epg_timezone");
            NSString *tzName = [[NSUserDefaults standardUserDefaults] stringForKey:@"ios6_iptv_epg_timezone_name"];
            if (!tzName || tzName.length == 0 || [tzName isEqualToString:@"System"]) {
                cell.detailTextLabel.text = LocalizedString(@"epg_timezone_system");
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
        } else if (indexPath.row == 1) {
            cell.textLabel.text = LocalizedString(@"epg_auto_scroll");
            NSInteger timeout = [EPGManager sharedManager].autoScrollTimeout;
            if (timeout == 0) {
                cell.detailTextLabel.text = LocalizedString(@"epg_auto_scroll_none");
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat:LocalizedString(@"epg_seconds_format"), (long)timeout];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            cell.textLabel.text = LocalizedString(@"auto_update_on_launch");
            cell.accessoryView = self.autoUpdateSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = LocalizedString(@"auto_update_on_expire");
            cell.accessoryView = self.autoExpireSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = LocalizedString(@"scheduled_update_time");
            NSString *timeStr = [EPGManager sharedManager].scheduledUpdateTimeString;
            cell.detailTextLabel.text = timeStr.length > 0 ? timeStr : LocalizedString(@"not_set");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
    } else if (indexPath.section == 4) {
        if (indexPath.row == 0) {
            cell.textLabel.text = LocalizedString(@"force_update_epg");
            cell.detailTextLabel.text = @"";
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
        if (indexPath.row == 0) {
            EPGTimeZoneListViewController *tzVC = [[EPGTimeZoneListViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:tzVC animated:YES];
        } else if (indexPath.row == 1) {
            EPGAutoScrollListViewController *scrollVC = [[EPGAutoScrollListViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:scrollVC animated:YES];
        }
    } else if (indexPath.section == 3 && indexPath.row == 2) {
        EPGScheduledTimeViewController *vc = [[EPGScheduledTimeViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else if (indexPath.section == 4) {
        if (indexPath.row == 0) {
            [self fetchEPGData];
        } else if (indexPath.row == 1) {
            [[EPGManager sharedManager] clearEPGCache];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:LocalizedString(@"epg_cache_cleared") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
            [alert show];
            [self.tableView reloadData];
        }
    }
}

@end