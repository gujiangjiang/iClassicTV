//
//  ImportViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "ImportViewController.h"

@interface ImportViewController ()
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UITextView *m3uTextView;
@end

@implementation ImportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"导入";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    // 【核心修复】：告诉 iOS 7 及以上系统，不要把内容画在导航栏下面！
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    CGFloat width = self.view.frame.size.width;
    
    // ------ 方式一：网络导入 ------
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
    
    // ------ 方式二：手动输入 ------
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 140, width - 40, 20)];
    label2.text = @"方式二：手动粘贴 M3U 文本";
    label2.font = [UIFont boldSystemFontOfSize:14];
    label2.backgroundColor = [UIColor clearColor];
    [self.view addSubview:label2];
    
    // 多行文本框
    self.m3uTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 165, width - 40, 120)];
    self.m3uTextView.layer.cornerRadius = 5.0;
    self.m3uTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.m3uTextView.layer.borderWidth = 1.0;
    [self.view addSubview:self.m3uTextView];
    
    UIButton *btnManual = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnManual.frame = CGRectMake(20, 290, width - 40, 40);
    [btnManual setTitle:@"载入上方文本" forState:UIControlStateNormal];
    [btnManual addTarget:self action:@selector(loadManualM3U) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnManual];
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
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误" message:@"下载失败，请检查网络或网址" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
            }
        });
    });
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
}

@end