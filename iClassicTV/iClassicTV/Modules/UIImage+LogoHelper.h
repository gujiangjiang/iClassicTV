//
//  UIImage+LogoHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 图像处理模块，专门用于处理频道 LOGO 相关的绘制与缩放
@interface UIImage (LogoHelper)

// 等比例缩放图片并居中，生成固定尺寸的图片 (Aspect Fit)
- (UIImage *)resizeAndPadToSize:(CGSize)targetSize;

// 动态生成默认LOGO (纯色背景 + 频道首字符)
+ (UIImage *)generateDefaultLogoWithName:(NSString *)name;

@end