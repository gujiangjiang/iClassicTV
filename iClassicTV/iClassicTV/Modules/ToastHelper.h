//
//  ToastHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 交互反馈模块
@interface ToastHelper : NSObject

// 模拟 iOS 风格的 Toast，自动消失
+ (void)showToastWithMessage:(NSString *)message;

@end