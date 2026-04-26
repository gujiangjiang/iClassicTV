//
//  M3UValidator.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "M3UValidator.h"

@implementation M3UValidator

+ (BOOL)isValidM3UString:(NSString *)m3uString {
    // 1. 判空校验
    if (!m3uString || m3uString.length == 0) {
        return NO;
    }
    
    // 2. 核心特征校验
    // 标准的 M3U 文件通常以 #EXTM3U 开头，并且包含 #EXTINF 频道信息
    // 为了兼容部分不规范但勉强能用的源，只要包含这两个特征之一即判定为格式有效
    BOOL hasExtM3U = [m3uString rangeOfString:@"#EXTM3U" options:NSCaseInsensitiveSearch].location != NSNotFound;
    BOOL hasExtInf = [m3uString rangeOfString:@"#EXTINF:" options:NSCaseInsensitiveSearch].location != NSNotFound;
    
    if (hasExtM3U || hasExtInf) {
        return YES;
    }
    
    return NO;
}

@end