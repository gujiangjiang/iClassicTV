//
//  PlayerEPGView.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PlayerEPGView;

// 新增：EPG 操作代理协议，用于回调给 Controller 处理跳转和刷新动作
@protocol PlayerEPGViewDelegate <NSObject>
@optional
// 点击了去设置按钮
- (void)epgViewDidTapSettings:(PlayerEPGView *)epgView;
// 点击了立即刷新按钮
- (void)epgViewDidTapRefresh:(PlayerEPGView *)epgView;
@end

// 独立的 EPG 节目单展示模块，包含顶部的日期选择器和底部的节目列表
@interface PlayerEPGView : UIView

// 接收外部传入的频道名称和 EPG 映射名称
@property (nonatomic, copy) NSString *channelTitle;
@property (nonatomic, copy) NSString *tvgName;

// 新增：操作代理
@property (nonatomic, weak) id<PlayerEPGViewDelegate> delegate;

// 加载/刷新 EPG 数据并重新渲染列表
- (void)reloadData;

// 自动滚动到当前时间正在播放的节目
- (void)scrollToCurrentProgram;

@end