//
//  UIViewController+ScrollToTop.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 全局视图控制器扩展模块：专门用于处理界面滚动到最上方的逻辑
@interface UIViewController (ScrollToTop)

// 自动寻找当前控制器视图堆栈中的 UIScrollView/UITableView 并让其动画滚动到顶部
- (void)scrollToTopAnimated:(BOOL)animated;

// 为当前控制器的导航栏 (NavigationBar) 统一添加双击回到最上方的手势
- (void)enableNavigationBarDoubleTapToScrollTop;

@end