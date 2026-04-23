//
//  M3UParser.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface M3UParser : NSObject
+ (NSArray *)parseM3UString:(NSString *)m3uString;
@end