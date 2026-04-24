//
//  NSString+EncodingHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "NSString+EncodingHelper.h"

@implementation NSString (EncodingHelper)

+ (NSString *)stringWithContentsOfFileWithFallback:(NSString *)path {
    if (!path) return nil;
    
    NSError *error = nil;
    // 优先尝试 UTF-8 编码读取
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!content) {
        // 失败则回退尝试 GBK/GB18030 编码读取
        NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        content = [NSString stringWithContentsOfFile:path encoding:gbkEncoding error:nil];
    }
    return content;
}

@end