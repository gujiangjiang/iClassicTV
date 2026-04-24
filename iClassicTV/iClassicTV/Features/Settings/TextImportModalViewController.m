//
//  TextImportModalViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TextImportModalViewController.h"

@interface TextImportModalViewController ()
@end

@implementation TextImportModalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"粘贴 M3U 文本";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction)];
    self.navigationItem.leftBarButtonItem = cancelBtn;
    
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithTitle:@"导入" style:UIBarButtonItemStyleDone target:self action:@selector(doneAction)];
    self.navigationItem.rightBarButtonItem = doneBtn;
    
    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.textView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 监听键盘弹出和隐藏通知，防止键盘死死遮挡底部的文本输入区域
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 页面消失时，移除键盘相关的通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark - Keyboard Notifications

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    // 获取键盘完全弹出后的 frame
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    // 将键盘的 frame 转换到当前视图的坐标系下，确保在不同方向下高度获取准确
    CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
    
    // 调整 textView 的内边距 (contentInset) 和滚动条内边距，为其底部留出键盘的高度空间
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardFrameInView.size.height, 0.0);
    self.textView.contentInset = contentInsets;
    self.textView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    // 键盘隐藏时，恢复 textView 原本的内边距
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.textView.contentInset = contentInsets;
    self.textView.scrollIndicatorInsets = contentInsets;
}

- (void)cancelAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneAction {
    if (self.textView.text.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入或粘贴 M3U 文本内容" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    if (self.completionHandler) {
        self.completionHandler(self.textView.text);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end