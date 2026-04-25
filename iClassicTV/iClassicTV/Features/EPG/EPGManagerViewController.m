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
    
    BOOL isDynamic = [EPGManager sharedManager].isDynamicEPGSource;
    NSInteger sectionsCount = isDynamic ? 1 : 3;
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
    return [EPGManager sharedManager].isEPGEnabled ? 4 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 1;
    if (section == 2) return 1;
    if (section == 3) return 2;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return LocalizedString(@"epg_source_settings");
    if (section == 2) return LocalizedString(@"epg_fetch_settings");
    if (section == 3) return LocalizedString(@"data_management");
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return LocalizedString(@"epg_switch_footer");
    if (section == 2) return LocalizedString(@"epg_auto_update_footer");
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
        cell.textLabel.text = LocalizedString(@"auto_update_on_launch");
        cell.accessoryView = self.autoUpdateSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    } else if (indexPath.section == 3) {
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
    } else if (indexPath.section == 3) {
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