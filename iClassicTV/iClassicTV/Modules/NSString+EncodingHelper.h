//
//  NSString+EncodingHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (EncodingHelper)

/// 尝试使用 UTF-8 读取网络 URL 内容，若失败则自动回退使用 GB18030/GBK 编码读取
/// @param url 网络或本地的 URL 对象
/// @return 解析后的字符串内容，如果全部失败则返回 nil
+ (NSString *)stringWithContentsOfURLWithFallback:(NSURL *)url;

/// 尝试使用 UTF-8 读取本地文件路径内容，若失败则自动回退使用 GB18030/GBK 编码读取
/// @param path 本地文件路径
/// @return 解析后的字符串内容，如果全部失败则返回 nil
+ (NSString *)stringWithContentsOfFileWithFallback:(NSString *)path;

@end