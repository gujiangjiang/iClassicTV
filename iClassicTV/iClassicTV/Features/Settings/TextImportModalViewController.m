//
//  TextImportModalViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TextImportModalViewController.h"
#import "LanguageManager.h" // 新增多语言

@interface TextImportModalViewController ()
@end

@implementation TextImportModalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"paste_m3u_text");
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction)];
    self.navigationItem.leftBarButtonItem = cancelBtn;
    
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithTitle:LocalizedString(@"import_btn") style:UIBarButtonItemStyleDone target:self action:@selector(doneAction)];
    self.navigationItem.rightBarButtonItem = doneBtn;
    
    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.textView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark - Keyboard Notifications

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardFrameInView.size.height, 0.0);
    self.textView.contentInset = contentInsets;
    self.textView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.textView.contentInset = contentInsets;
    self.textView.scrollIndicatorInsets = contentInsets;
}

- (void)cancelAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneAction {
    if (self.textView.text.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"tips") message:LocalizedString(@"enter_m3u_content") delegate:nil cancelButtonTitle:LocalizedString(@"confirm") otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    if (self.completionHandler) {
        self.completionHandler(self.textView.text);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end