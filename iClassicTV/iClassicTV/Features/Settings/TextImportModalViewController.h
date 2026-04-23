//
//  TextImportModalViewController.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 多行文本输入弹窗，用于导入本地文本源
@interface TextImportModalViewController : UIViewController

@property (nonatomic, copy) void (^completionHandler)(NSString *text);
@property (nonatomic, strong) UITextView *textView;

@end