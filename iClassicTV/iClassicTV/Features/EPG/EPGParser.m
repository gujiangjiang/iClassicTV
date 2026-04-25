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
// [优化] 新增字符集属性，避免在循环中重复创建字符集对象，提升解析效率
@property (nonatomic, strong) NSCharacterSet *normalizeCharacterSet;

@end

@implementation EPGParser

+ (NSDictionary *)parseEPGXMLData:(NSData *)xmlData {
    if (!xmlData || xmlData.length == 0) return nil;
    
    EPGParser *parserObj = [[EPGParser alloc] init];
    // [优化] 虽然入口保留 NSData 兼容，但内部逻辑已改为流式思路，尽量减少内存拷贝
    return [parserObj parseData:xmlData];
}

- (NSDictionary *)parseData:(NSData *)xmlData {
    self.channelIdToName = [NSMutableDictionary dictionary];
    self.channelNameToPrograms = [NSMutableDictionary dictionary];
    self.currentChars = [NSMutableString string];
    
    // [优化] 预先初始化归一化用的字符集
    self.normalizeCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"-_ "];
    
    // 初始化时间解析器，XMLTV 时间格式一般为：20260425120000 +0800
    self.dateFormatterWithZone = [[NSDateFormatter alloc] init];
    [self.dateFormatterWithZone setDateFormat:@"yyyyMMddHHmmss Z"];
    
    self.dateFormatterSimple = [[NSDateFormatter alloc] init];
    [self.dateFormatterSimple setDateFormat:@"yyyyMMddHHmmss"];
    
    // [优化] 使用 NSInputStream 进行流式解析，避免 NSData 占用连续的大块内存，这在 iOS 6 上对防止 OOM 至关重要
    NSInputStream *inputStream = [NSInputStream inputStreamWithData:xmlData];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithStream:inputStream];
    parser.delegate = self;
    
    // [优化] 开启此项可以减少对命名空间的处理，进一步提升解析速度
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    [parser setShouldResolveExternalEntities:NO];
    
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
    // [优化] 仅在必要节点执行去空格操作，减少不必要的 CPU 开销
    
    if ([elementName isEqualToString:@"display-name"]) {
        NSString *trimmedChars = [self.currentChars stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // 获取并归一化频道名称
        if (self.currentChannelId && trimmedChars.length > 0) {
            NSString *normalizedName = [self normalizeChannelName:trimmedChars];
            self.channelIdToName[self.currentChannelId] = normalizedName;
        }
    } else if ([elementName isEqualToString:@"title"]) {
        if (self.currentProgram) {
            self.currentProgram.title = [self.currentChars stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
    } else if ([elementName isEqualToString:@"programme"]) {
        // 节目节点结束，将该节目归入对应的频道数组中
        if (self.currentProgram && self.currentProgramChannelId) {
            NSString *normalizedName = self.channelIdToName[self.currentProgramChannelId];
            if (normalizedName) {
                NSMutableArray *programs = self.channelNameToPrograms[normalizedName];
                if (!programs) {
                    // [优化] 预估每个频道每天约有 20-30 个节目，初始化容量减少动态扩容
                    programs = [NSMutableArray arrayWithCapacity:25];
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
    
    // [优化] 使用预设的字符集属性替代临时创建，大幅降低内存抖动
    NSArray *components = [name componentsSeparatedByCharactersInSet:self.normalizeCharacterSet];
    return [[components componentsJoinedByString:@""] lowercaseString];
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