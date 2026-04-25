//
//  EPGManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EPGProgram.h"

@interface EPGManager : NSObject

+ (instancetype)sharedManager;

// 全局电子节目单功能开关
@property (nonatomic, assign) BOOL isEPGEnabled;

// 当前设置的 EPG 接口 URL
@property (nonatomic, copy) NSString *epgSourceURL;

// 异步下载并解析 EPG 数据
- (void)fetchAndParseEPGDataWithCompletion:(void(^)(BOOL success, NSString *errorMsg))completion;

// 清理本地 EPG 缓存
- (void)clearEPGCache;

// 获取某个频道的全部节目单（内部自带模糊匹配处理）
- (NSArray *)programsForChannelName:(NSString *)channelName;

// 获取某个频道正在播放的当前节目
- (EPGProgram *)currentProgramForChannelName:(NSString *)channelName;

@end