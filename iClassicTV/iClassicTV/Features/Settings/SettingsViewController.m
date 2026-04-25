//
//  SettingsViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "SettingsViewController.h"
#import "SourceManagerViewController.h"
#import "AboutViewController.h"
#import "UAManagerViewController.h"
#import "AppDataManager.h"
#import "UIViewController+ScrollToTop.h"
#import "DataManagementViewController.h"
#import "LanguageManager.h"
#import "EPGManagerViewController.h"
#import "PlayerSettingsViewController.h"

@interface SettingsViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *currentAvailableLanguages;
@end

@implementation SettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self enableNavigationBarDoubleTapToScrollTop];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLanguageChange) name:@"LanguageDidChangeNotification" object:nil];
    
    [self setupLocalizedTexts];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupLocalizedTexts {
    self.title = LocalizedString(@"settings");
    
    // 确保从设置页面进入的子页面，其顶部的返回按钮也是多语言的
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"back") style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.navigationItem.backBarButtonItem = backItem;
    
    // 修复：使用 LocalizedString 替换硬编码的 EPG 和 播放器设置
    self.sections = @[
                      @{@"title": LocalizedString(@"source_settings"), @"rows": @[LocalizedString(@"my_sources_manage"), LocalizedString(@"epg_manager_title")]},
                      @{@"title": LocalizedString(@"software_settings"), @"rows": @[LocalizedString(@"language_settings"), LocalizedString(@"player_settings_title"), LocalizedString(@"ua_settings")]},
                      @{@"title": LocalizedString(@"data_and_security"), @"rows": @[LocalizedString(@"data_management_and_backup")]},
                      @{@"title": LocalizedString(@"about"), @"rows": @[LocalizedString(@"about_iclassictv")]}
                      ];
}

- (void)handleLanguageChange {
    [self setupLocalizedTexts];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.sections[section][@"rows"] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.sections[section][@"title"]; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    
    cell.textLabel.text = self.sections[indexPath.section][@"rows"][indexPath.row];
    cell.detailTextLabel.text = @"";
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.textLabel.textColor = [UIColor blackColor];
    
    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            NSString *savedMode = [LanguageManager sharedManager].savedLanguageCode;
            if ([savedMode isEqualToString:@"system"]) {
                cell.detailTextLabel.text = LocalizedString(@"follow_system");
            } else {
                cell.detailTextLabel.text = [[LanguageManager sharedManager] currentLanguageDisplayName];
            }
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self.navigationController pushViewController:[[SourceManagerViewController alloc] init] animated:YES];
        } else if (indexPath.row == 1) {
            [self.navigationController pushViewController:[[EPGManagerViewController alloc] init] animated:YES];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            self.currentAvailableLanguages = [[LanguageManager sharedManager] availableLanguages];
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"language_settings") delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:LocalizedString(@"follow_system"), nil];
            for (NSDictionary *lang in self.currentAvailableLanguages) {
                [sheet addButtonWithTitle:lang[@"name"]];
            }
            [sheet addButtonWithTitle:LocalizedString(@"cancel")];
            sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
            sheet.tag = 201;
            [sheet showInView:self.view];
        } else if (indexPath.row == 1) {
            PlayerSettingsViewController *playerVC = [[PlayerSettingsViewController alloc] init];
            [self.navigationController pushViewController:playerVC animated:YES];
        } else if (indexPath.row == 2) {
            UAManagerViewController *uaVC = [[UAManagerViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:uaVC animated:YES];
        }
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        DataManagementViewController *dataVC = [[DataManagementViewController alloc] init];
        [self.navigationController pushViewController:dataVC animated:YES];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        [self.navigationController pushViewController:[[AboutViewController alloc] init] animated:YES];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    if (actionSheet.tag == 201) {
        if (buttonIndex == 0) {
            [[LanguageManager sharedManager] changeLanguageTo:@"system"];
        } else {
            NSDictionary *selectedLang = self.currentAvailableLanguages[buttonIndex - 1];
            [[LanguageManager sharedManager] changeLanguageTo:selectedLang[@"code"]];
        }
    }
}

@end