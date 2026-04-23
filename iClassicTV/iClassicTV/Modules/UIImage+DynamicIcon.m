//
//  UIImage+DynamicIcon.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UIImage+DynamicIcon.h"

@implementation UIImage (DynamicIcon)

+ (UIImage *)dynamicPlayTabBarIcon {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(10, 6)];
    [path addLineToPoint:CGPointMake(24, 15)];
    [path addLineToPoint:CGPointMake(10, 24)];
    [path closePath];
    
    [[UIColor blackColor] setFill];
    [path fill];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)dynamicSettingsTabBarIcon {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    [[UIColor blackColor] setFill];
    
    // 第一行滑动条
    [[UIBezierPath bezierPathWithRect:CGRectMake(4, 8, 22, 2)] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10, 5, 8, 8)] fill];
    
    // 第二行滑动条
    [[UIBezierPath bezierPathWithRect:CGRectMake(4, 15, 22, 2)] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18, 12, 8, 8)] fill];
    
    // 第三行滑动条
    [[UIBezierPath bezierPathWithRect:CGRectMake(4, 22, 22, 2)] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(6, 19, 8, 8)] fill];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)dynamicLockIconWithState:(BOOL)locked {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    [[UIColor whiteColor] setStroke];
    [[UIColor whiteColor] setFill];
    
    // 锁身 (底部矩形)
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7, 14, 16, 11) cornerRadius:2];
    [body fill];
    
    // 锁环 (顶部 U 型)
    UIBezierPath *shackle = [UIBezierPath bezierPath];
    if (locked) {
        // 闭合状态
        [shackle moveToPoint:CGPointMake(10, 14)];
        [shackle addLineToPoint:CGPointMake(10, 9)];
        [shackle addArcWithCenter:CGPointMake(15, 9) radius:5 startAngle:M_PI endAngle:0 clockwise:YES];
        [shackle addLineToPoint:CGPointMake(20, 14)];
    } else {
        // 开启状态 (向上偏移并断开)
        [shackle moveToPoint:CGPointMake(10, 10)];
        [shackle addLineToPoint:CGPointMake(10, 5)];
        [shackle addArcWithCenter:CGPointMake(15, 5) radius:5 startAngle:M_PI endAngle:0 clockwise:YES];
        [shackle addLineToPoint:CGPointMake(20, 8)];
    }
    shackle.lineWidth = 2.5;
    [shackle stroke];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end