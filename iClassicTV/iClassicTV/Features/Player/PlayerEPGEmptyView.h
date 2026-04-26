//
//  PlayerEPGEmptyView.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 定义空视图的各种状态
typedef NS_ENUM(NSInteger, EPGEmptyStateType) {
    EPGEmptyStateTypeNone,          // 隐藏状态（有数据时）
    EPGEmptyStateTypeNotEnabled,    // EPG 未开启
    EPGEmptyStateTypeNoData,        // 无节目数据
    EPGEmptyStateTypeExpired,       // 节目已过期
    EPGEmptyStateTypeLoading        // 正在加载中
};

@protocol PlayerEPGEmptyViewDelegate <NSObject>
@optional
- (void)emptyViewDidTapSettings;
- (void)emptyViewDidTapRefresh;
@end

// 独立出的状态提示空视图组件
@interface PlayerEPGEmptyView : UIView

@property (nonatomic, weak) id<PlayerEPGEmptyViewDelegate> delegate;

// [新增] 标识是否为动态接口，如果是，空状态刷新按钮将显示为“重试”
@property (nonatomic, assign) BOOL isDynamicSource;

// 根据传入的状态自动更新 UI 呈现
- (void)setState:(EPGEmptyStateType)state;

@end