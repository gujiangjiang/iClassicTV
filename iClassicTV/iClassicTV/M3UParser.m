//
//  M3UParser.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "M3UParser.h"
#import "Channel.h"

@implementation M3UParser

+ (NSString *)extractAttribute:(NSString *)attrName fromString:(NSString *)string {
    // 增加容错：支持空格或不同引号
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"([^\"]+)\"", attrName];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
    if (match) {
        return [string substringWithRange:[match rangeAtIndex:1]];
    }
    return nil;
}

+ (NSArray *)parseM3UString:(NSString *)m3uString {
    if (!m3uString || m3uString.length == 0) return @[];
    
    // 兼容 Windows (\r\n) 和 Unix (\n) 换行符
    NSArray *lines = [m3uString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *channels = [NSMutableArray array];
    NSMutableDictionary *channelsMap = [NSMutableDictionary dictionary];
    
    Channel *tempChannel = nil;
    
    for (NSString *rawLine in lines) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length == 0) continue;
        
        if ([line hasPrefix:@"#EXTINF:"]) {
            tempChannel = [[Channel alloc] init];
            tempChannel.logo = [self extractAttribute:@"tvg-logo" fromString:line] ?: @"";
            
            // 优先提取 group-title，如果没有则标记为“其他”
            tempChannel.group = [self extractAttribute:@"group-title" fromString:line] ?: @"未分组频道";
            
            // 提取频道名：取最后一个逗号之后的所有内容
            NSRange commaRange = [line rangeOfString:@"," options:NSBackwardsSearch];
            if (commaRange.location != NSNotFound) {
                NSString *name = [line substringFromIndex:commaRange.location + 1];
                // 仅修剪首尾空格，不使用正则，防止误伤 4K 或 576 等标识符
                tempChannel.name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            } else {
                tempChannel.name = @"未知频道";
            }
        }
        else if (([line hasPrefix:@"http://"] || [line hasPrefix:@"https://"]) && tempChannel) {
            // 唯一标识：分组名 + 频道名
            NSString *uniqueKey = [NSString stringWithFormat:@"%@-%@", tempChannel.group, tempChannel.name];
            
            Channel *existingChannel = channelsMap[uniqueKey];
            if (!existingChannel) {
                [tempChannel.urls addObject:line];
                [channels addObject:tempChannel]; // 按照 M3U 出现的先后顺序加入数组
                channelsMap[uniqueKey] = tempChannel;
            } else {
                // 同名频道合并线路
                if (![existingChannel.urls containsObject:line]) {
                    [existingChannel.urls addObject:line];
                }
            }
            tempChannel = nil;
        }
    }
    return channels;
}
@end