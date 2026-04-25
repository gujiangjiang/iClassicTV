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
    if (self) { _urls = [NSMutableArray array]; }
    return self;
}

- (NSString *)persistenceKey {
    // 优先使用 tvgName，其次使用频道名，确保记忆的准确性
    NSString *identifier = (self.tvgName.length > 0) ? self.tvgName : self.name;
    return [NSString stringWithFormat:@"SourcePref_%@_%@", self.group, identifier];
}

// [新增] 统一返回 logo 的缓存 Key 逻辑
- (NSString *)logoIdentifier {
    return self.logo.length > 0 ? self.logo : self.name;
}

@end