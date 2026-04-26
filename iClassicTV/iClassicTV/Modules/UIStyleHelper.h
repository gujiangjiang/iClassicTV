//
//  UIStyleHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIStyleHelper : NSObject

// 判断当前是否为 iOS 7 及以上系统
+ (BOOL)isIOS7OrLater;

// 统一应用容器背景样式 (iOS 6 拟物化渐变 vs iOS 7+ 扁平化)
+ (void)applyGlobalStyleToView:(UIView *)view;

// 统一应用文字样式 (iOS 6 雕刻阴影 vs iOS 7+ 标准)
+ (void)applyTextStyleToLabel:(UILabel *)label isBold:(BOOL)isBold fontSize:(CGFloat)size;

// 统一应用进度条样式
+ (void)applyProgressStyleToView:(UIProgressView *)progressView;

// 统一应用列表样式 (针对节目单等列表的背景与分隔符)
+ (void)applyTableStyleToTableView:(UITableView *)tableView;

@end