//
//  AlertHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AlertHelper.h"
#import "ToastHelper.h" // 引入 ToastHelper 用于无按钮时的拦截处理
#import <objc/runtime.h>

#pragma mark - 普通提示框代理

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

#pragma mark - 双输入框代理

// 新增：私有的双输入框代理类，用于拦截事件并提取两个文本框的内容
@interface AlertDoubleInputDelegate : NSObject <UIAlertViewDelegate>
@property (nonatomic, copy) AlertDoubleInputBlock confirmBlock;
@property (nonatomic, copy) AlertCancelBlock cancelBlock;
@end

@implementation AlertDoubleInputDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        if (self.cancelBlock) {
            self.cancelBlock();
        }
    } else {
        if (self.confirmBlock) {
            UITextField *nameField = [alertView textFieldAtIndex:0];
            UITextField *contentField = [alertView textFieldAtIndex:1];
            self.confirmBlock(nameField.text, contentField.text);
        }
    }
    // 回调完成后，移除关联对象
    objc_setAssociatedObject(alertView, @"AlertDoubleInputDelegate", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark - AlertHelper 实现

@implementation AlertHelper

+ (void)showConfirmAlertWithTitle:(NSString *)title
                          message:(NSString *)message
                     confirmTitle:(NSString *)confirmTitle
                      cancelTitle:(NSString *)cancelTitle
                     confirmBlock:(AlertConfirmBlock)confirmBlock
                      cancelBlock:(AlertCancelBlock)cancelBlock {
    
    // 如果确认按钮和取消按钮都为空，说明原本意图是展示一个无按钮的 Toast 提示
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

// 新增：双输入框提取后的独立功能模块
+ (void)showDoubleInputAlertWithTitle:(NSString *)title
                              message:(NSString *)message
                      namePlaceholder:(NSString *)namePlaceholder
                   contentPlaceholder:(NSString *)contentPlaceholder
                             nameText:(NSString *)nameText
                          contentText:(NSString *)contentText
                         keyboardType:(UIKeyboardType)keyboardType
                         confirmTitle:(NSString *)confirmTitle
                          cancelTitle:(NSString *)cancelTitle
                         confirmBlock:(AlertDoubleInputBlock)confirmBlock
                          cancelBlock:(AlertCancelBlock)cancelBlock {
    
    AlertDoubleInputDelegate *delegate = [[AlertDoubleInputDelegate alloc] init];
    delegate.confirmBlock = confirmBlock;
    delegate.cancelBlock = cancelBlock;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:delegate
                                          cancelButtonTitle:cancelTitle
                                          otherButtonTitles:confirmTitle, nil];
    
    // 使用自带的 LoginAndPassword 样式来实现双输入框布局
    alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    
    UITextField *nameField = [alert textFieldAtIndex:0];
    nameField.placeholder = namePlaceholder;
    if (nameText) nameField.text = nameText;
    
    UITextField *contentField = [alert textFieldAtIndex:1];
    contentField.placeholder = contentPlaceholder;
    if (contentText) contentField.text = contentText;
    contentField.keyboardType = keyboardType;
    // 关键：取消密码框固有的圆点遮挡，使其变为明文输入
    contentField.secureTextEntry = NO;
    
    // 保活代理
    objc_setAssociatedObject(alert, @"AlertDoubleInputDelegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [alert show];
}

@end