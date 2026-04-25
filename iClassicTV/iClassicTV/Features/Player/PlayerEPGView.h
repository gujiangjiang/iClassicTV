//
//  PlayerEPGView.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 独立的 EPG 节目单展示模块，用于在播放界面底部显示频道对应的节目表
@interface PlayerEPGView : UIView

// 接收外部传入的频道名称和 EPG 映射名称
@property (nonatomic, copy) NSString *channelTitle;
@property (nonatomic, copy) NSString *tvgName;

// 加载/刷新 EPG 数据并重新渲染列表
- (void)reloadData;

// 自动滚动到当前时间正在播放的节目
- (void)scrollToCurrentProgram;

@end