//
//  Channel.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Channel : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *logo;
@property (nonatomic, copy) NSString *group;
@property (nonatomic, copy) NSString *tvgName; // 用于记忆线路的唯一标识
@property (nonatomic, copy) NSString *catchupSource; // 新增：直播回放 (Catchup) 的链接模板
@property (nonatomic, strong) NSMutableArray *urls;

// 辅助方法：获取用于持久化存储的唯一 Key
- (NSString *)persistenceKey;

@end