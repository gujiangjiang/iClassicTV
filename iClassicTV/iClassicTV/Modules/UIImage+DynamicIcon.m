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

+ (UIImage *)dynamicPlaybackIconWithState:(BOOL)isPlaying {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [[UIColor whiteColor] setFill];
    
    if (isPlaying) {
        // 正在播放，显示暂停图标 (两条垂直矩形)
        [[UIBezierPath bezierPathWithRect:CGRectMake(8, 7, 4, 16)] fill];
        [[UIBezierPath bezierPathWithRect:CGRectMake(18, 7, 4, 16)] fill];
    } else {
        // 已经暂停，显示播放图标 (向右的三角形)
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(10, 6)];
        [path addLineToPoint:CGPointMake(24, 15)];
        [path addLineToPoint:CGPointMake(10, 24)];
        [path closePath];
        [path fill];
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)dynamicFullscreenIconWithState:(BOOL)isFullscreen {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    [[UIColor whiteColor] setStroke];
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    if (!isFullscreen) {
        // 左上
        [path moveToPoint:CGPointMake(6, 12)];
        [path addLineToPoint:CGPointMake(6, 6)];
        [path addLineToPoint:CGPointMake(12, 6)];
        // 右上
        [path moveToPoint:CGPointMake(18, 6)];
        [path addLineToPoint:CGPointMake(24, 6)];
        [path addLineToPoint:CGPointMake(24, 12)];
        // 右下
        [path moveToPoint:CGPointMake(24, 18)];
        [path addLineToPoint:CGPointMake(24, 24)];
        [path addLineToPoint:CGPointMake(18, 24)];
        // 左下
        [path moveToPoint:CGPointMake(12, 24)];
        [path addLineToPoint:CGPointMake(6, 24)];
        [path addLineToPoint:CGPointMake(6, 18)];
    } else {
        // 左上
        [path moveToPoint:CGPointMake(12, 6)];
        [path addLineToPoint:CGPointMake(12, 12)];
        [path addLineToPoint:CGPointMake(6, 12)];
        // 右上
        [path moveToPoint:CGPointMake(18, 6)];
        [path addLineToPoint:CGPointMake(18, 12)];
        [path addLineToPoint:CGPointMake(24, 12)];
        // 右下
        [path moveToPoint:CGPointMake(24, 18)];
        [path addLineToPoint:CGPointMake(18, 18)];
        [path addLineToPoint:CGPointMake(18, 24)];
        // 左下
        [path moveToPoint:CGPointMake(12, 24)];
        [path addLineToPoint:CGPointMake(12, 18)];
        [path addLineToPoint:CGPointMake(6, 18)];
    }
    path.lineWidth = 2.0;
    path.lineCapStyle = kCGLineCapSquare;
    path.lineJoinStyle = kCGLineJoinMiter;
    [path stroke];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// [新增] 动态绘制播放器画面中央的大型圆形播放图标
+ (UIImage *)dynamicLargeCenterPlayIcon {
    CGSize size = CGSizeMake(80, 80);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    // 半透明黑色圆形背景
    [[UIColor colorWithWhite:0.0 alpha:0.5] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 80, 80)] fill];
    
    // 增加一个淡白色的描边边框提升质感
    [[UIColor colorWithWhite:1.0 alpha:0.8] setStroke];
    UIBezierPath *border = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(2, 2, 76, 76)];
    border.lineWidth = 2.0;
    [border stroke];
    
    // 白色播放三角形
    [[UIColor colorWithWhite:1.0 alpha:0.9] setFill];
    UIBezierPath *path = [UIBezierPath bezierPath];
    // 经过数学计算，将三角形重心点严格对齐在 X=40, Y=40，达到完美的视觉居中
    [path moveToPoint:CGPointMake(30, 24)];
    [path addLineToPoint:CGPointMake(56, 40)];
    [path addLineToPoint:CGPointMake(30, 56)];
    [path closePath];
    [path fill];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end