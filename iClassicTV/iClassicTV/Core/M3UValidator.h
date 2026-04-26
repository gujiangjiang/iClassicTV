//
//  M3UValidator.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface M3UValidator : NSObject

/// 校验 M3U 字符串格式是否有效
/// @param m3uString M3U 文件内容
/// @return 是否有效
+ (BOOL)isValidM3UString:(NSString *)m3uString;

@end