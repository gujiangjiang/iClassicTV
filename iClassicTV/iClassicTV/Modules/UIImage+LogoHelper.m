//
//  UIImage+LogoHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UIImage+LogoHelper.h"

@implementation UIImage (LogoHelper)

- (UIImage *)resizeAndPadToSize:(CGSize)targetSize {
    CGFloat scaleRatio = MIN(targetSize.width / self.size.width, targetSize.height / self.size.height);
    CGSize scaledSize = CGSizeMake(self.size.width * scaleRatio, self.size.height * scaleRatio);
    
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, [UIScreen mainScreen].scale);
    
    CGFloat x = (targetSize.width - scaledSize.width) / 2.0;
    CGFloat y = (targetSize.height - scaledSize.height) / 2.0;
    [self drawInRect:CGRectMake(x, y, scaledSize.width, scaledSize.height)];
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}

+ (UIImage *)generateDefaultLogoWithName:(NSString *)name {
    CGSize size = CGSizeMake(40, 40);
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    NSUInteger hash = name.hash;
    CGFloat r = ((hash & 0xFF0000) >> 16) / 255.0;
    CGFloat g = ((hash & 0x00FF00) >> 8) / 255.0;
    CGFloat b = (hash & 0x0000FF) / 255.0;
    UIColor *bgColor = [UIColor colorWithRed:(r + 1.0)/2.0 green:(g + 1.0)/2.0 blue:(b + 1.0)/2.0 alpha:1.0];
    
    [bgColor setFill];
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    
    NSString *firstChar = name.length > 0 ? [name substringToIndex:1] : @"T";
    UIFont *font = [UIFont boldSystemFontOfSize:18];
    UIColor *textColor = [UIColor darkGrayColor];
    
    CGSize textSize = [firstChar sizeWithFont:font];
    CGRect textRect = CGRectMake((size.width - textSize.width) / 2.0, (size.height - textSize.height) / 2.0, textSize.width, textSize.height);
    [textColor set];
    [firstChar drawInRect:textRect withFont:font];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end