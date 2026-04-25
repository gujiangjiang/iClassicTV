//
//  M3UParser.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "M3UParser.h"
#import "Channel.h"
#import "LanguageManager.h" // 新增多语言

@implementation M3UParser

+ (NSString *)extractValueWithRegex:(NSRegularExpression *)regex fromString:(NSString *)string {
    if (!regex || !string) return nil;
    NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
    if (match) return [string substringWithRange:[match rangeAtIndex:1]];
    return nil;
}

// 新增：利用正则从 M3U 文件中提取全局自带的 EPG 地址
+ (NSString *)extractEPGUrlsFromM3UString:(NSString *)m3uString {
    if (!m3uString || m3uString.length == 0) return nil;
    
    // 匹配如：#EXTM3U x-tvg-url="https://live.fanmingming.com/e.xml,http://e.erw.cc/all.xml.gz"
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"#EXTM3U.*x-tvg-url\\s*=\\s*\"([^\"]+)\"" options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:m3uString options:0 range:NSMakeRange(0, m3uString.length)];
    
    if (match) {
        return [m3uString substringWithRange:[match rangeAtIndex:1]];
    }
    return nil;
}

+ (NSArray *)parseM3UString:(NSString *)m3uString {
    if (!m3uString) return @[];
    
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
            tempChannel.logo = [self extractValueWithRegex:logoRegex fromString:line] ?: @"";
            tempChannel.tvgName = [self extractValueWithRegex:nameRegex fromString:line] ?: @"";
            // 替换未分组
            tempChannel.group = [self extractValueWithRegex:groupRegex fromString:line] ?: LocalizedString(@"ungrouped");
            
            NSRange commaRange = [line rangeOfString:@"," options:NSBackwardsSearch];
            if (commaRange.location != NSNotFound) {
                tempChannel.name = [[line substringFromIndex:commaRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
        }
        else if (([line hasPrefix:@"http://"] || [line hasPrefix:@"https://"]) && tempChannel) {
            NSString *uniqueKey = [NSString stringWithFormat:@"%@|||%@", tempChannel.group, tempChannel.name];
            Channel *existing = channelsMap[uniqueKey];
            
            if (!existing) {
                [tempChannel.urls addObject:line];
                [channels addObject:tempChannel];
                channelsMap[uniqueKey] = tempChannel;
            } else {
                [existing.urls addObject:line];
                if (existing.tvgName.length == 0) existing.tvgName = tempChannel.tvgName;
            }
            tempChannel = nil;
        }
    }
    return channels;
}
@end