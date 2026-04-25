//
//  AlertHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (^AlertConfirmBlock)(void);
typedef void (^AlertCancelBlock)(void);

// 新增：双输入框回调 Block，返回名称和内容
typedef void (^AlertDoubleInputBlock)(NSString *name, NSString *content);

@interface AlertHelper : NSObject

/**
 * 显示一个包含确认和取消回调的通用提示框（兼容 iOS 6）
 *
 * @param title        弹窗标题
 * @param message      弹窗内容
 * @param confirmTitle 确认按钮文字
 * @param cancelTitle  取消按钮文字
 * @param confirmBlock 点击确认后的回调 Block
 * @param cancelBlock  点击取消后的回调 Block (可传 nil)
 */
+ (void)showConfirmAlertWithTitle:(NSString *)title
                          message:(NSString *)message
                     confirmTitle:(NSString *)confirmTitle
                      cancelTitle:(NSString *)cancelTitle
                     confirmBlock:(AlertConfirmBlock)confirmBlock
                      cancelBlock:(AlertCancelBlock)cancelBlock;

/**
 * 显示一个双输入框的弹窗（兼容 iOS 6，用于同时输入备注名和内容/链接）
 *
 * @param title              弹窗标题
 * @param message            弹窗内容
 * @param namePlaceholder    第一个输入框（名称）的占位符
 * @param contentPlaceholder 第二个输入框（内容）的占位符
 * @param nameText           第一个输入框的默认文本（可为 nil）
 * @param contentText        第二个输入框的默认文本（可为 nil）
 * @param keyboardType       第二个输入框的键盘类型
 * @param confirmTitle       确认按钮文字
 * @param cancelTitle        取消按钮文字
 * @param confirmBlock       点击确认后的回调 Block（包含两个输入框的文本）
 * @param cancelBlock        点击取消后的回调 Block (可传 nil)
 */
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
                          cancelBlock:(AlertCancelBlock)cancelBlock;

@end