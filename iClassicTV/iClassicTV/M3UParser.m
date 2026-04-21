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
    NSString *pattern = [NSString stringWithFormat:@"%@=\"([^\"]+)\"", attrName];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
    if (match) {
        return [string substringWithRange:[match rangeAtIndex:1]];
    }
    return nil;
}

+ (NSArray *)parseM3UString:(NSString *)m3uString {
    NSArray *lines = [m3uString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *channels = [NSMutableArray array];
    NSMutableDictionary *channelsMap = [NSMutableDictionary dictionary];
    
    Channel *tempChannel = nil;
    
    for (NSString *rawLine in lines) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0) continue;
        
        if ([line hasPrefix:@"#EXTINF:"]) {
            tempChannel = [[Channel alloc] init];
            tempChannel.logo = [self extractAttribute:@"tvg-logo" fromString:line] ?: @"";
            tempChannel.group = [self extractAttribute:@"group-title" fromString:line] ?: @"未分组";
            
            NSRange commaRange = [line rangeOfString:@"," options:NSBackwardsSearch];
            if (commaRange.location != NSNotFound) {
                tempChannel.name = [[line substringFromIndex:commaRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            } else {
                tempChannel.name = @"未命名频道";
            }
        }
        else if (([line hasPrefix:@"http://"] || [line hasPrefix:@"https://"]) && tempChannel) {
            NSString *uniqueKey = [NSString stringWithFormat:@"%@|||%@", tempChannel.group, tempChannel.name];
            
            Channel *existingChannel = channelsMap[uniqueKey];
            if (!existingChannel) {
                [tempChannel.urls addObject:line];
                [channels addObject:tempChannel];
                channelsMap[uniqueKey] = tempChannel;
            } else {
                // 触发同源合并逻辑
                [existingChannel.urls addObject:line];
                if (existingChannel.logo.length == 0 && tempChannel.logo.length > 0) {
                    existingChannel.logo = tempChannel.logo;
                }
            }
            tempChannel = nil; // 重置
        }
    }
    return channels;
}
@end