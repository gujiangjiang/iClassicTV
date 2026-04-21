//
//  Channel.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "Channel.h"

@implementation Channel
- (instancetype)init {
    self = [super init];
    if (self) {
        _urls = [NSMutableArray array];
    }
    return self;
}
@end
