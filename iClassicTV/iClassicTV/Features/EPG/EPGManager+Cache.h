//
//  EPGManager+Cache.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"

@interface EPGManager (Cache)

// 缓存加载与保存
- (void)loadCacheFromDisk;
- (void)saveCacheToDisk:(NSDictionary *)dataDict;

// 清理本地 EPG 缓存
- (void)clearEPGCache;

@end