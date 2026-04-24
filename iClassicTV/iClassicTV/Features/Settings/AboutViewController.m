//
//  AboutViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AboutViewController.h"
#import "LanguageManager.h" // 新增多语言

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LocalizedString(@"about");
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, self.view.bounds.size.height - 40)];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    textView.font = [UIFont systemFontOfSize:15];
    textView.text = LocalizedString(@"about_app_desc");
    [self.view addSubview:textView];
}

@end