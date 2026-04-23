//
//  TextImportModalViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TextImportModalViewController.h"

@implementation TextImportModalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"本地文本源";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 增加导航栏按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"下一步" style:UIBarButtonItemStyleDone target:self action:@selector(done)];
    
    // 初始化多行文本输入框
    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:self.textView];
    
    // 自动弹出键盘
    [self.textView becomeFirstResponder];
}

- (void)cancel {
    [self.textView resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)done {
    if (self.textView.text.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"内容不能为空" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [self.textView resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.completionHandler) {
            self.completionHandler(self.textView.text);
        }
    }];
}

@end