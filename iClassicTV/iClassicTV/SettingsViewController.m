//
//  SettingsViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "SettingsViewController.h"

#pragma mark - 网络导入子页面
// =========================================================
@interface WebImportViewController : UIViewController
@property (nonatomic, strong) UITextField *urlField;
@end

@implementation WebImportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"网络导入";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    // 告诉 iOS 7 及以上系统，不要把内容画在导航栏下面！
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    CGFloat width = self.view.frame.size.width;
    
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, width - 40, 20)];
    label1.text = @"方式一：网络导入";
    label1.font = [UIFont boldSystemFontOfSize:14];
    label1.backgroundColor = [UIColor clearColor];
    [self.view addSubview:label1];
    
    self.urlField = [[UITextField alloc] initWithFrame:CGRectMake(20, 40, width - 40, 40)];
    self.urlField.borderStyle = UITextBorderStyleRoundedRect;
    self.urlField.placeholder = @"输入 M3U 网址 (http://...)";
    self.urlField.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.urlField];
    
    UIButton *btnLoad = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnLoad.frame = CGRectMake(20, 85, width - 40, 40);
    [btnLoad setTitle:@"下载并载入" forState:UIControlStateNormal];
    [btnLoad addTarget:self action:@selector(loadRemoteM3U) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnLoad];
}

- (void)loadRemoteM3U {
    [self.urlField resignFirstResponder]; // 收起键盘
    NSURL *url = [NSURL URLWithString:self.urlField.text];
    if (!url) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"网址无效" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSString *m3uData = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (m3uData) {
                [[NSUserDefaults standardUserDefaults] setObject:m3uData forKey:@"ios6_iptv_m3u"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"成功" message:@"直播源已载入！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
                [self.navigationController popViewControllerAnimated:YES]; // 成功后返回上一级菜单
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误" message:@"下载失败，请检查网络或网址" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
            }
        });
    });
}
@end


#pragma mark - 文本导入子页面
// =========================================================
@interface TextImportViewController : UIViewController
@property (nonatomic, strong) UITextView *m3uTextView;
@end

@implementation TextImportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"文本导入";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    // 告诉 iOS 7 及以上系统，不要把内容画在导航栏下面！
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    CGFloat width = self.view.frame.size.width;
    
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, width - 40, 20)];
    label2.text = @"方式二：手动粘贴 M3U 文本";
    label2.font = [UIFont boldSystemFontOfSize:14];
    label2.backgroundColor = [UIColor clearColor];
    [self.view addSubview:label2];
    
    // 多行文本框
    self.m3uTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 40, width - 40, 150)];
    self.m3uTextView.layer.cornerRadius = 5.0;
    self.m3uTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.m3uTextView.layer.borderWidth = 1.0;
    [self.view addSubview:self.m3uTextView];
    
    UIButton *btnManual = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnManual.frame = CGRectMake(20, 200, width - 40, 40);
    [btnManual setTitle:@"载入上方文本" forState:UIControlStateNormal];
    [btnManual addTarget:self action:@selector(loadManualM3U) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnManual];
}

- (void)loadManualM3U {
    [self.m3uTextView resignFirstResponder]; // 收起键盘
    NSString *m3uData = self.m3uTextView.text;
    
    if (m3uData.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请先粘贴内容" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // 保存并刷新
    [[NSUserDefaults standardUserDefaults] setObject:m3uData forKey:@"ios6_iptv_m3u"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"成功" message:@"本地文本源已载入！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alert show];
    [self.navigationController popViewControllerAnimated:YES]; // 成功后返回上一级菜单
}
@end


#pragma mark - 关于软件子页面
// =========================================================
@interface AboutViewController : UIViewController
@end

@implementation AboutViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"关于";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    // 告诉 iOS 7 及以上系统，不要把内容画在导航栏下面！
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(20, 20, self.view.frame.size.width - 40, 250)];
    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    textView.font = [UIFont systemFontOfSize:15];
    textView.text = @"iClassicTV (Native iOS 6 Edition)\n\n一款专为怀旧党和老旧 iOS 设备（如 iPhone 4/4s、iPad 2/3）打造的纯原生 IPTV / M3U 直播源播放器。\n\n• 纯正拟物化 UI\n• 硬件级解码播放\n• 智能线路记忆\n\n版本: 1.0\n作者: gujiangjiang\n开源协议: MIT License";
    [self.view addSubview:textView];
}
@end


#pragma mark - 设置主菜单 (重命名为 SettingsViewController)
// =========================================================
@interface SettingsViewController () <UIAlertViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSArray *sections;
@end

@implementation SettingsViewController

// 覆盖默认初始化，确保使用 Grouped 样式的列表
- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    
    // 构建设置菜单数据源
    self.sections = @[
                      @{@"title": @"直播源设置", @"rows": @[@"直播源网络导入", @"直播源文本导入", @"清空目前直播源"]},
                      @{@"title": @"软件设置", @"rows": @[@"默认全屏逻辑", @"清空缓存 (记忆与偏好)"]},
                      @{@"title": @"关于", @"rows": @[@"关于 iClassicTV"]}
                      ];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *rows = self.sections[section][@"rows"];
    return rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        // 使用 Value1 样式，右侧可以显示当前设置项的文字
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSArray *rows = self.sections[indexPath.section][@"rows"];
    cell.textLabel.text = rows[indexPath.row];
    cell.detailTextLabel.text = @""; // 避免 cell 复用导致文字残留
    
    // 针对具有破坏性操作的按钮进行标红，去掉箭头
    if (indexPath.section == 0 && indexPath.row == 2) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor redColor];
    } else if (indexPath.section == 1 && indexPath.row == 1) { // 清空缓存
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor redColor];
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    // 显示当前的“默认全屏逻辑”配置
    if (indexPath.section == 1 && indexPath.row == 0) {
        NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        if (pref == 1) {
            cell.detailTextLabel.text = @"横屏";
        } else if (pref == 2) {
            cell.detailTextLabel.text = @"竖屏";
        } else {
            cell.detailTextLabel.text = @"跟随系统";
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES]; // 取消选中状态
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            // 跳转网络导入
            WebImportViewController *webVC = [[WebImportViewController alloc] init];
            [self.navigationController pushViewController:webVC animated:YES];
        } else if (indexPath.row == 1) {
            // 跳转文本导入
            TextImportViewController *textVC = [[TextImportViewController alloc] init];
            [self.navigationController pushViewController:textVC animated:YES];
        } else if (indexPath.row == 2) {
            // 弹出清空直播源确认框
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"警告" message:@"确定要清空所有的直播源吗？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定清空", nil];
            alert.tag = 101; // 利用 tag 区分不同弹窗
            [alert show];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            // 弹出全屏逻辑选择菜单
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"默认全屏逻辑" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"跟随系统", @"横屏", @"竖屏", nil];
            sheet.tag = 201;
            [sheet showInView:self.view];
        } else if (indexPath.row == 1) {
            // 弹出清空缓存确认框
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"清空缓存" message:@"确定要清空所有的线路记忆偏好吗？(图片缓存将在下次重启时自动清理)" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            alert.tag = 102;
            [alert show];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            // 跳转关于页面
            AboutViewController *aboutVC = [[AboutViewController alloc] init];
            [self.navigationController pushViewController:aboutVC animated:YES];
        }
    }
}

#pragma mark - UIActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 201 && buttonIndex != actionSheet.cancelButtonIndex) {
        // buttonIndex 顺序：0=跟随系统, 1=横屏, 2=竖屏
        [[NSUserDefaults standardUserDefaults] setInteger:buttonIndex forKey:@"PlayerOrientationPref"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadData]; // 刷新列表以显示最新的状态
    }
}

#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        if (alertView.tag == 101) {
            // 执行清空直播源操作
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ios6_iptv_m3u"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UDataUpdated" object:nil]; // 发送更新通知，刷新首页列表
            
            UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"直播源已全部清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [successAlert show];
        } else if (alertView.tag == 102) {
            // 执行清空缓存操作 (遍历 NSUserDefaults 中以 SourcePref_ 为前缀的线路记忆并删除)
            NSDictionary *defaultsDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
            for (NSString *key in [defaultsDict allKeys]) {
                if ([key hasPrefix:@"SourcePref_"]) {
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
                }
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"已清空" message:@"记忆缓存已清空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [successAlert show];
        }
    }
}

@end