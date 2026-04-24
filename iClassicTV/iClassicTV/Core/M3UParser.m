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

// 优化：将提取方法修改为接收预编译好的正则表达式对象，避免在循环中重复创建
+ (NSString *)extractValueWithRegex:(NSRegularExpression *)regex fromString:(NSString *)string {
    if (!regex || !string) return nil;
    NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
    if (match) return [string substringWithRange:[match rangeAtIndex:1]];
    return nil;
}

+ (NSArray *)parseM3UString:(NSString *)m3uString {
    if (!m3uString) return @[];
    
    // 优化：在循环外部初始化并复用正则表达式，解决解析大量频道时的性能瓶颈
    NSRegularExpression *logoRegex = [NSRegularExpression regularExpressionWithPattern:@"tvg-logo\\s*=\\s*\"([^\"]+)\"" options:NSRegularExpressionCaseInsensitive error:nil];
    NSRegularExpression *nameRegex = [NSRegularExpression regularExpressionWithPattern:@"tvg-name\\s*=\\s*\"([^\"]+)\"" options:NSRegularExpressionCaseInsensitive error:nil];
    NSRegularExpression *groupRegex = [NSRegularExpression regularExpressionWithPattern:@"group-title\\s*=\\s*\"([^\"]+)\"" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSArray *lines = [m3uString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *channels = [NSMutableArray array];
    NSMutableDictionary *channelsMap = [NSMutableDictionary dictionary];
    Channel *tempChannel = nil;
    
    for (NSString *rawLine in lines) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length == 0) continue;
        
        if ([line hasPrefix:@"#EXTINF:"]) {
            tempChannel = [[Channel alloc] init];
            // 优化：使用预编译的正则对象提取属性
            tempChannel.logo = [self extractValueWithRegex:logoRegex fromString:line] ?: @"";
            tempChannel.tvgName = [self extractValueWithRegex:nameRegex fromString:line] ?: @"";
            tempChannel.group = [self extractValueWithRegex:groupRegex fromString:line] ?: @"未分组";
            
            NSRange commaRange = [line rangeOfString:@"," options:NSBackwardsSearch];
            if (commaRange.location != NSNotFound) {
                tempChannel.name = [[line substringFromIndex:commaRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
        }
        else if (([line hasPrefix:@"http://"] || [line hasPrefix:@"https://"]) && tempChannel) {
            // 使用 分组+名字 作为聚合 Key
            NSString *uniqueKey = [NSString stringWithFormat:@"%@|||%@", tempChannel.group, tempChannel.name];
            Channel *existing = channelsMap[uniqueKey];
            
            if (!existing) {
                [tempChannel.urls addObject:line];
                [channels addObject:tempChannel];
                channelsMap[uniqueKey] = tempChannel;
            } else {
                // 如果发现同名频道，将 URL 加入现有频道的数组
                [existing.urls addObject:line];
                if (existing.tvgName.length == 0) existing.tvgName = tempChannel.tvgName;
            }
            tempChannel = nil;
        }
    }
    return channels;
}
@end