//
//  EPGManager+Query.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager+Query.h"
#import "EPGManager+Internal.h"

@implementation EPGManager (Query)

#pragma mark - Query (XML)

- (NSString *)normalizeQueryName:(NSString *)name {
    if (!name || name.length == 0) return @"";
    
    // [优化] 使用预设的字符集属性，避免频繁 alloc 字符集，显著减少在节目列表滚动时的 CPU 瞬时负载。
    NSArray *components = [name componentsSeparatedByCharactersInSet:self.queryNormalizeSet];
    return [[components componentsJoinedByString:@""] lowercaseString];
}

- (NSArray *)programsForChannelName:(NSString *)channelName {
    if (!self.isEPGEnabled || self.isDynamicEPGSource || !self.epgCacheDict || channelName.length == 0) return nil;
    
    NSString *normalizedName = [self normalizeQueryName:channelName];
    NSArray *programs = self.epgCacheDict[normalizedName];
    
    if (!programs || programs.count == 0) {
        // [优化] 将后缀过滤条件改为一次性匹配，减少字符串拷贝
        NSString *fallbackName = [normalizedName stringByReplacingOccurrencesOfString:@"4k" withString:@""];
        fallbackName = [fallbackName stringByReplacingOccurrencesOfString:@"8k" withString:@""];
        fallbackName = [fallbackName stringByReplacingOccurrencesOfString:@"hd" withString:@""];
        fallbackName = [fallbackName stringByReplacingOccurrencesOfString:@"fhd" withString:@""];
        if (![fallbackName isEqualToString:normalizedName]) {
            programs = self.epgCacheDict[fallbackName];
        }
    }
    return programs;
}

- (EPGProgram *)currentProgramForChannelName:(NSString *)channelName {
    NSArray *programs = [self programsForChannelName:channelName];
    if (!programs || programs.count == 0) return nil;
    
    NSDate *now = [NSDate date];
    // [优化] 针对已排序的节目单，可以采用二分查找（Binary Search）进一步优化，但在 iOS 6 上考虑到单频道节目不多，线性查找已足够
    for (EPGProgram *program in programs) {
        if ([now compare:program.startTime] != NSOrderedAscending &&
            [now compare:program.endTime] != NSOrderedDescending) {
            return program;
        }
    }
    return nil;
}

#pragma mark - Dynamic Query

- (void)fetchDynamicProgramsForChannelName:(NSString *)channelName date:(NSDate *)date completion:(void(^)(NSArray *programs))completion {
    if (!channelName || channelName.length == 0 || !date) {
        if (completion) completion(nil);
        return;
    }
    
    NSString *urlStr = self.epgSourceURL;
    if (urlStr.length == 0) {
        if (completion) completion(nil);
        return;
    }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setTimeZone:self.epgTimeZone];
    [df setDateFormat:@"yyyy-MM-dd"];
    NSString *dateStr = [df stringFromDate:date];
    NSString *encodedChannel = [channelName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSString *finalURLStr;
    if ([urlStr rangeOfString:@"?"].location != NSNotFound) {
        finalURLStr = [NSString stringWithFormat:@"%@&ch=%@&date=%@", urlStr, encodedChannel, dateStr];
    } else {
        finalURLStr = [NSString stringWithFormat:@"%@?ch=%@&date=%@", urlStr, encodedChannel, dateStr];
    }
    
    NSURL *url = [NSURL URLWithString:finalURLStr];
    if (!url) {
        if (completion) completion(nil);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Mobile/10B329 iClassicTV" forHTTPHeaderField:@"User-Agent"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil); });
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error || !json || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil); });
            return;
        }
        
        NSArray *epgData = json[@"epg_data"];
        if (!epgData || ![epgData isKindOfClass:[NSArray class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil); });
            return;
        }
        
        NSMutableArray *programs = [NSMutableArray array];
        
        NSTimeZone *cstZone = self.epgTimeZone;
        NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
        [timeFormatter setTimeZone:cstZone];
        [timeFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
        
        NSDateFormatter *timeFormatterWithSeconds = [[NSDateFormatter alloc] init];
        [timeFormatterWithSeconds setTimeZone:cstZone];
        [timeFormatterWithSeconds setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        for (NSDictionary *item in epgData) {
            NSString *start = item[@"start"];
            NSString *end = item[@"end"];
            NSString *title = item[@"title"];
            
            if (!start || !title) continue;
            
            NSString *startFullStr = [NSString stringWithFormat:@"%@ %@", dateStr, start];
            NSDate *startDate = [start componentsSeparatedByString:@":"].count == 3 ? [timeFormatterWithSeconds dateFromString:startFullStr] : [timeFormatter dateFromString:startFullStr];
            
            NSDate *endDate = nil;
            if (end) {
                NSString *endFullStr = [NSString stringWithFormat:@"%@ %@", dateStr, end];
                endDate = [end componentsSeparatedByString:@":"].count == 3 ? [timeFormatterWithSeconds dateFromString:endFullStr] : [timeFormatter dateFromString:endFullStr];
            }
            
            if (startDate && title) {
                EPGProgram *p = [[EPGProgram alloc] init];
                p.title = title;
                p.startTime = startDate;
                if (endDate) {
                    if ([endDate compare:startDate] == NSOrderedAscending) {
                        endDate = [endDate dateByAddingTimeInterval:86400];
                    }
                    p.endTime = endDate;
                }
                [programs addObject:p];
            }
        }
        
        for (NSInteger i = 0; i < programs.count; i++) {
            EPGProgram *p = programs[i];
            if (!p.endTime) {
                if (i < programs.count - 1) {
                    EPGProgram *nextP = programs[i+1];
                    p.endTime = nextP.startTime;
                } else {
                    p.endTime = [p.startTime dateByAddingTimeInterval:1800];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(programs);
        });
    });
}

@end