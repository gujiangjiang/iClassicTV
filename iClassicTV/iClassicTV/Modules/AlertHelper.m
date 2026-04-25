//
//  AlertHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AlertHelper.h"
#import "ToastHelper.h" // 新增：引入 ToastHelper 用于无按钮时的拦截处理
#import <objc/runtime.h>

// 私有的代理类，用于拦截 UIAlertView 的点击事件并转换为 Block 回调
@interface AlertHelperDelegate : NSObject <UIAlertViewDelegate>
@property (nonatomic, copy) AlertConfirmBlock confirmBlock;
@property (nonatomic, copy) AlertCancelBlock cancelBlock;
@end

@implementation AlertHelperDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        if (self.cancelBlock) {
            self.cancelBlock();
        }
    } else {
        if (self.confirmBlock) {
            self.confirmBlock();
        }
    }
    // 回调完成后，移除 Runtime 关联对象，打破循环引用，使其能够正常释放
    objc_setAssociatedObject(alertView, @"AlertHelperDelegate", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation AlertHelper

+ (void)showConfirmAlertWithTitle:(NSString *)title
                          message:(NSString *)message
                     confirmTitle:(NSString *)confirmTitle
                      cancelTitle:(NSString *)cancelTitle
                     confirmBlock:(AlertConfirmBlock)confirmBlock
                      cancelBlock:(AlertCancelBlock)cancelBlock {
    
    // 优化：如果确认按钮和取消按钮都为空，说明原本意图是展示一个无按钮的 Toast 提示
    // 原生 UIAlertView 在 iOS 6 无按钮时会预留底部空白区域，因此在此拦截并转交由 ToastHelper 处理
    if (!confirmTitle && !cancelTitle) {
        NSString *toastMessage = @"";
        if (title.length > 0 && message.length > 0) {
            toastMessage = [NSString stringWithFormat:@"%@\n%@", title, message];
        } else if (message.length > 0) {
            toastMessage = message;
        } else {
            toastMessage = title;
        }
        [ToastHelper showToastWithMessage:toastMessage];
        return;
    }
    
    AlertHelperDelegate *delegate = [[AlertHelperDelegate alloc] init];
    delegate.confirmBlock = confirmBlock;
    delegate.cancelBlock = cancelBlock;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:delegate
                                          cancelButtonTitle:cancelTitle
                                          otherButtonTitles:confirmTitle, nil];
    
    // 由于局部变量 delegate 在方法结束后会被释放，使用 Runtime 将其与 UIAlertView 强关联
    // 保证在用户点击弹窗按钮之前，delegate 始终存活
    objc_setAssociatedObject(alert, @"AlertHelperDelegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [alert show];
}

@end