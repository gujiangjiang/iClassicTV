//
//  EPGManager+Sources.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"

@interface EPGManager (Sources)

// 加载与保存
- (void)loadSourcesFromDisk;
- (void)saveSourcesToDisk;

// EPG 源管理方法 (支持普通源添加)
- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url type:(NSString *)type;

// 新增：添加带 M3U 绑定关系的专用内置 EPG 源
- (void)addEPGSourceWithName:(NSString *)name url:(NSString *)url type:(NSString *)type linkedM3UId:(NSString *)linkedM3UId;

// 删除/修改普通源
- (void)removeEPGSourceAtIndex:(NSInteger)index;
- (void)renameEPGSourceAtIndex:(NSInteger)index withName:(NSString *)name url:(NSString *)url type:(NSString *)type;
- (void)setActiveEPGSourceAtIndex:(NSInteger)index;

// 新增：自动管理绑定 M3U 的源 (由 AppDataManager 调用)
- (void)removeEPGSourceByLinkedM3UId:(NSString *)m3uId;
- (void)updateLinkedEPGSourceName:(NSString *)name forM3UId:(NSString *)m3uId;
- (void)removeAllLinkedEPGSources;

@end