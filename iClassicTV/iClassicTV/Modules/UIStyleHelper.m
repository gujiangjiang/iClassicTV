//
//  UIStyleHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UIStyleHelper.h"
#import <QuartzCore/QuartzCore.h>

@implementation UIStyleHelper

+ (BOOL)isIOS7OrLater {
    return ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0);
}

+ (void)applyGlobalStyleToView:(UIView *)view {
    if ([self isIOS7OrLater]) {
        // iOS 7+ 扁平化：纯色半透明 + 圆角
        view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
        view.layer.cornerRadius = 8.0;
        view.layer.masksToBounds = YES;
        // 移除可能存在的旧图层
        for (CALayer *layer in view.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]]) {
                [layer removeFromSuperlayer];
            }
        }
    } else {
        // iOS 6 拟物化：立体阴影 + 水晶渐变 + 高光边框
        view.backgroundColor = [UIColor clearColor];
        view.layer.shadowColor = [UIColor blackColor].CGColor;
        view.layer.shadowOffset = CGSizeMake(0, 3);
        view.layer.shadowOpacity = 0.6;
        view.layer.shadowRadius = 4.0;
        
        // 检查是否已经添加过渐变层，避免重复添加
        CAGradientLayer *gradient = nil;
        for (CALayer *layer in view.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]]) {
                gradient = (CAGradientLayer *)layer;
                break;
            }
        }
        
        if (!gradient) {
            gradient = [CAGradientLayer layer];
            [view.layer insertSublayer:gradient atIndex:0];
        }
        
        gradient.frame = view.bounds;
        gradient.cornerRadius = 8.0;
        gradient.colors = [NSArray arrayWithObjects:
                           (id)[UIColor colorWithWhite:0.25 alpha:0.9].CGColor,
                           (id)[UIColor colorWithWhite:0.1 alpha:0.9].CGColor,
                           nil];
        gradient.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        gradient.borderWidth = 1.0;
    }
}

+ (void)applyTextStyleToLabel:(UILabel *)label isBold:(BOOL)isBold fontSize:(CGFloat)size {
    if ([self isIOS7OrLater]) {
        label.font = isBold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
        label.shadowColor = nil;
        label.shadowOffset = CGSizeZero;
    } else {
        // iOS 6 拟物化：强制使用粗体并增加刻字效果
        label.font = [UIFont boldSystemFontOfSize:size];
        label.shadowColor = [UIColor blackColor];
        label.shadowOffset = CGSizeMake(0, -1);
    }
}

+ (void)applyProgressStyleToView:(UIProgressView *)progressView {
    if ([self isIOS7OrLater]) {
        progressView.progressTintColor = [UIColor whiteColor];
        progressView.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    } else {
        // iOS 6 使用默认的水晶蓝色果冻样式，不作强制颜色修改以保留原始质感
    }
}

+ (void)applyTableStyleToTableView:(UITableView *)tableView {
    if ([self isIOS7OrLater]) {
        tableView.backgroundColor = [UIColor clearColor];
        tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    } else {
        // iOS 6 拟物化列表通常带有较深的纹理背景或特定颜色
        tableView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
        tableView.separatorColor = [UIColor blackColor];
    }
}

@end