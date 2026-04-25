//
//  EPGParser.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EPGParser : NSObject

// 传入下载好的 XML 数据，解析并返回按频道名称（归一化后）分组的节目单字典
// 返回格式: NSDictionary<NSString *, NSArray<EPGProgram *> *>
+ (NSDictionary *)parseEPGXMLData:(NSData *)xmlData;

@end