//
//  M3UParser.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface M3UParser : NSObject

+ (NSArray *)parseM3UString:(NSString *)m3uString;

// 新增：提取 M3U 头部定义的 x-tvg-url 链接（可能是逗号分隔的多个链接）
+ (NSString *)extractEPGUrlsFromM3UString:(NSString *)m3uString;

@end