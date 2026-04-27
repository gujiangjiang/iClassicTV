//
//  PlayerEPGView.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PlayerEPGView, EPGProgram;

@protocol PlayerEPGViewDelegate <NSObject>
@optional
- (void)epgViewDidTapSettings:(PlayerEPGView *)epgView;
- (void)epgViewDidTapRefresh:(PlayerEPGView *)epgView;
// 用户在列表中点击某个节目时触发（用于回放）
- (void)epgView:(PlayerEPGView *)epgView didSelectProgram:(EPGProgram *)program;
@end

@interface PlayerEPGView : UIView

@property (nonatomic, weak) id<PlayerEPGViewDelegate> delegate;

// 频道信息，用于查询 EPG 和记录预约数据
@property (nonatomic, copy) NSString *channelTitle;
@property (nonatomic, copy) NSString *tvgName;
@property (nonatomic, copy) NSString *videoURLString; // [新增] 用于保存预约记录的URL
@property (nonatomic, copy) NSString *catchupSource;  // [新增] 用于保存预约记录的回放参数

// 标识该频道是否支持回看，以便开启列表点击交互
@property (nonatomic, assign) BOOL supportsCatchup;

// 记录当前正在回放的节目对象，用于 UI 状态变更
@property (nonatomic, strong) EPGProgram *replayingProgram;

// 通知组件刷新数据或切换频道时重置
- (void)reloadData;

// 主动要求列表滚动至当前正在播放（或正在回放）的节目
- (void)scrollToCurrentProgram;

// 获取当前正在播放和即将播放的节目，供全屏悬浮窗调用
- (EPGProgram *)currentPlayingProgram;
- (EPGProgram *)nextPlayingProgram;

// 定时检查节目单是否需要更新状态并自动滚动
- (void)updateTimeTick;

@end