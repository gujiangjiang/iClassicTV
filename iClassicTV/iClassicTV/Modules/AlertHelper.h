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

@end