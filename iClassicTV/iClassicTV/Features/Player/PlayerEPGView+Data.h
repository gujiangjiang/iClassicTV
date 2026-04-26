//
//  PlayerEPGView+Data.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView.h"
#import "PlayerEPGEmptyView.h"

// 在分类声明中遵循协议，并声明需要暴露给其他组件调用的方法
@interface PlayerEPGView (Data) <PlayerEPGEmptyViewDelegate>

- (void)data_reloadData;
- (NSDate *)startOfDayForDate:(NSDate *)date;
- (void)handleScrollAfterDataLoadForDate:(NSDate *)date;
- (void)fetchAndDisplayDynamicEPGForDate:(NSDate *)date channel:(NSString *)channelName;

@end