//
//  PlayerEPGDateBar.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PlayerEPGDateBar;

@protocol PlayerEPGDateBarDelegate <NSObject>
// 用户点击了某个日期
- (void)dateBar:(PlayerEPGDateBar *)dateBar didSelectDateAtIndex:(NSInteger)index;

@optional
// 抛出滑动事件给主视图以接管定时器逻辑
- (void)dateBarWillBeginDragging:(PlayerEPGDateBar *)dateBar;
- (void)dateBarDidEndDragging:(PlayerEPGDateBar *)dateBar willDecelerate:(BOOL)decelerate;
- (void)dateBarDidEndDecelerating:(PlayerEPGDateBar *)dateBar;
@end

// 独立出的顶部日期选择栏组件
@interface PlayerEPGDateBar : UIView

@property (nonatomic, weak) id<PlayerEPGDateBarDelegate> delegate;

// 刷新顶部日期数据
- (void)updateWithDates:(NSArray *)dates;

// 高亮指定的日期按钮并移动指示条
- (void)highlightDateButtonAtIndex:(NSInteger)index animated:(BOOL)animated;

// 复位滚动位置到最左侧
- (void)resetScrollPosition;

@end