//
//  NSString+EncodingHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (EncodingHelper)

/// 尝试使用 UTF-8 读取本地文件路径内容，若失败则自动回退使用 GB18030/GBK 编码读取
/// @param path 本地文件路径
/// @return 解析后的字符串内容，如果全部失败则返回 nil
+ (NSString *)stringWithContentsOfFileWithFallback:(NSString *)path;

/// [新增] 将可能含有中文或特殊字符的字符串安全转换为 NSURL
/// 先尝试直接解析，失败后自动进行 UTF8 百分号编码再解析
/// @return 解析成功的 NSURL，若解析失败返回 nil
- (NSURL *)toSafeURL;

@end