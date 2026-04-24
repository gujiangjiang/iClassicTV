//
//  UserAgentManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserAgentManager : NSObject

// 获取单例对象
+ (instancetype)sharedManager;

// 获取当前正在使用的完整 User-Agent 字符串
- (NSString *)currentUA;

// 获取所有的 UA 列表数据 (包含 name, ua, isDefault 字段)
- (NSArray *)allUAs;

// 获取当前选中的索引
- (NSInteger)currentSelectedIndex;

// 选择并启用某一个 UA
- (void)selectUAAtIndex:(NSInteger)index;

// 新增自定义的 UA
- (void)addUAWithName:(NSString *)name uaString:(NSString *)uaString;

// 删除自定义的 UA（会自动拦截并阻止删除索引为 0 的默认 UA）
- (BOOL)deleteUAAtIndex:(NSInteger)index;

@end