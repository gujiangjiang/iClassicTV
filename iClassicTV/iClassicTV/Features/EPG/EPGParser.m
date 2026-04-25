//
//  EPGParser.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGParser.h"
#import "EPGProgram.h"

@interface EPGParser () <NSXMLParserDelegate>

@property (nonatomic, strong) NSMutableDictionary *channelIdToName;       // 映射 channel id 到 频道名称
@property (nonatomic, strong) NSMutableDictionary *channelNameToPrograms; // 最终结果：频道名称 -> 节目列表

@property (nonatomic, copy) NSString *currentElementName;
@property (nonatomic, copy) NSString *currentChannelId;
@property (nonatomic, strong) EPGProgram *currentProgram;
@property (nonatomic, copy) NSString *currentProgramChannelId;
@property (nonatomic, strong) NSMutableString *currentChars;
@property (nonatomic, strong) NSDateFormatter *dateFormatterWithZone;
@property (nonatomic, strong) NSDateFormatter *dateFormatterSimple;

@end

@implementation EPGParser

+ (NSDictionary *)parseEPGXMLData:(NSData *)xmlData {
    if (!xmlData || xmlData.length == 0) return nil;
    
    EPGParser *parserObj = [[EPGParser alloc] init];
    return [parserObj parseData:xmlData];
}

- (NSDictionary *)parseData:(NSData *)xmlData {
    self.channelIdToName = [NSMutableDictionary dictionary];
    self.channelNameToPrograms = [NSMutableDictionary dictionary];
    self.currentChars = [NSMutableString string];
    
    // 初始化时间解析器，XMLTV 时间格式一般为：20260425120000 +0800
    self.dateFormatterWithZone = [[NSDateFormatter alloc] init];
    [self.dateFormatterWithZone setDateFormat:@"yyyyMMddHHmmss Z"];
    
    self.dateFormatterSimple = [[NSDateFormatter alloc] init];
    [self.dateFormatterSimple setDateFormat:@"yyyyMMddHHmmss"];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
    parser.delegate = self;
    [parser parse];
    
    return [NSDictionary dictionaryWithDictionary:self.channelNameToPrograms];
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    self.currentElementName = elementName;
    [self.currentChars setString:@""]; // 清空字符缓存，准备接收新节点的内容
    
    if ([elementName isEqualToString:@"channel"]) {
        self.currentChannelId = attributeDict[@"id"];
    } else if ([elementName isEqualToString:@"programme"]) {
        self.currentProgram = [[EPGProgram alloc] init];
        self.currentProgramChannelId = attributeDict[@"channel"];
        
        // 解析开始和结束时间
        NSString *startStr = attributeDict[@"start"];
        NSString *stopStr = attributeDict[@"stop"];
        self.currentProgram.startTime = [self dateFromString:startStr];
        self.currentProgram.endTime = [self dateFromString:stopStr];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.currentChars appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    NSString *trimmedChars = [self.currentChars stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([elementName isEqualToString:@"display-name"]) {
        // 获取并归一化频道名称
        if (self.currentChannelId && trimmedChars.length > 0) {
            NSString *normalizedName = [self normalizeChannelName:trimmedChars];
            self.channelIdToName[self.currentChannelId] = normalizedName;
        }
    } else if ([elementName isEqualToString:@"title"]) {
        if (self.currentProgram) {
            self.currentProgram.title = trimmedChars;
        }
    } else if ([elementName isEqualToString:@"programme"]) {
        // 节目节点结束，将该节目归入对应的频道数组中
        if (self.currentProgram && self.currentProgramChannelId) {
            NSString *normalizedName = self.channelIdToName[self.currentProgramChannelId];
            if (normalizedName) {
                NSMutableArray *programs = self.channelNameToPrograms[normalizedName];
                if (!programs) {
                    programs = [NSMutableArray array];
                    self.channelNameToPrograms[normalizedName] = programs;
                }
                [programs addObject:self.currentProgram];
            }
        }
        self.currentProgram = nil;
        self.currentProgramChannelId = nil;
    }
}

// 核心模糊匹配：归一化频道名称，移除横杠、下划线、空格并转小写
- (NSString *)normalizeChannelName:(NSString *)name {
    if (!name || name.length == 0) return @"";
    NSMutableString *normalized = [NSMutableString stringWithString:[name lowercaseString]];
    [normalized replaceOccurrencesOfString:@"-" withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    [normalized replaceOccurrencesOfString:@"_" withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    [normalized replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, normalized.length)];
    
    // 针对您提到的 4K/8K 等后缀，如果在 EPG 中包含 4k/8k 关键字，这里暂时予以保留，
    // 以便后续 M3U 播放列表查询时进行精准或降级匹配
    return [NSString stringWithString:normalized];
}

- (NSDate *)dateFromString:(NSString *)dateStr {
    if (!dateStr || dateStr.length < 14) return nil;
    
    // 带有 +0800 时区的情况
    if (dateStr.length >= 18) {
        return [self.dateFormatterWithZone dateFromString:dateStr];
    } else {
        // 截取前 14 位，按本地时区处理
        NSString *subStr = [dateStr substringToIndex:14];
        return [self.dateFormatterSimple dateFromString:subStr];
    }
}

@end