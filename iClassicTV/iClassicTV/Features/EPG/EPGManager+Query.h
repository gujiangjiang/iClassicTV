//
//  EPGManager+Query.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"

@interface EPGManager (Query)

// 内部归一化处理
- (NSString *)normalizeQueryName:(NSString *)name;

// 获取某个频道的全部节目单（内部自带模糊匹配处理）
- (NSArray *)programsForChannelName:(NSString *)channelName;

// 获取某个频道正在播放的当前节目
- (EPGProgram *)currentProgramForChannelName:(NSString *)channelName;

// --- DIYP / EPGInfo 动态 EPG 管理 ---
- (void)fetchDynamicProgramsForChannelName:(NSString *)channelName date:(NSDate *)date completion:(void(^)(NSArray *programs))completion;

@end