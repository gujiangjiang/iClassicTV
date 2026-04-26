//
//  EPGManager+Update.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"

@interface EPGManager (Update)

// 内部调用方法声明
- (void)startAutoUpdateTimer;
- (BOOL)needsUpdate;
- (void)performSilentBackgroundUpdate;
- (BOOL)isGzippedData:(NSData *)data;
- (NSData *)gunzippedData:(NSData *)data;

// 异步下载并解析 EPG 数据 (内部已支持多 URL 回退互补合并)
- (void)fetchAndParseEPGDataWithCompletion:(void(^)(BOOL success, NSString *errorMsg))completion;

// 后台静默检查并自动更新
- (void)checkAndAutoUpdateEPG;

@end