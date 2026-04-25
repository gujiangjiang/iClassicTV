//
//  EPGProgram.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EPGProgram : NSObject <NSCoding>

@property (nonatomic, copy) NSString *title;        // 节目名称 (例如：新闻联播)
@property (nonatomic, strong) NSDate *startTime;    // 节目开始时间
@property (nonatomic, strong) NSDate *endTime;      // 节目结束时间

@end