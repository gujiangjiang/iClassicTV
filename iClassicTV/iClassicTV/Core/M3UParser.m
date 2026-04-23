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
    NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*\"([^\"]+)\"", attrName];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
    if (match) return [string substringWithRange:[match rangeAtIndex:1]];
    return nil;
}

+ (NSArray *)parseM3UString:(NSString *)m3uString {
    if (!m3uString) return @[];
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
            tempChannel.tvgName = [self extractAttribute:@"tvg-name" fromString:line] ?: @"";
            tempChannel.group = [self extractAttribute:@"group-title" fromString:line] ?: @"未分组";
            
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