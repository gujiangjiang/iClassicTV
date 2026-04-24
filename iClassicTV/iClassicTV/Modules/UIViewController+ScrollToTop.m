//
//  UIViewController+ScrollToTop.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UIViewController+ScrollToTop.h"

@implementation UIViewController (ScrollToTop)

- (void)scrollToTopAnimated:(BOOL)animated {
    // 自动寻找当前视图层级中存在的滚动视图 (比如 UITableView)
    UIScrollView *scrollView = [self findScrollViewInView:self.view];
    if (scrollView) {
        // 考虑到可能存在的内边距(contentInset)，计算出最精确的顶部偏移量
        CGPoint topOffset = CGPointMake(0, -scrollView.contentInset.top);
        [scrollView setContentOffset:topOffset animated:animated];
    }
}

// 递归查找视图层级中的 UIScrollView
- (UIScrollView *)findScrollViewInView:(UIView *)view {
    // 如果视图本身就是 UIScrollView 的子类 (包括 UITableView)
    if ([view isKindOfClass:[UIScrollView class]]) {
        return (UIScrollView *)view;
    }
    // 否则遍历其子视图进行查找
    for (UIView *subview in view.subviews) {
        UIScrollView *found = [self findScrollViewInView:subview];
        if (found) {
            return found;
        }
    }
    return nil;
}

- (void)enableNavigationBarDoubleTapToScrollTop {
    if (self.navigationController && self.navigationController.navigationBar) {
        UINavigationBar *navBar = self.navigationController.navigationBar;
        
        // 遍历检查是否已经添加过双击手势，防止多次 push 时重复添加导致冲突
        BOOL hasDoubleTap = NO;
        for (UIGestureRecognizer *gesture in navBar.gestureRecognizers) {
            if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                UITapGestureRecognizer *tap = (UITapGestureRecognizer *)gesture;
                if (tap.numberOfTapsRequired == 2) {
                    hasDoubleTap = YES;
                    break;
                }
            }
        }
        
        // 如果没有添加过，则为导航栏挂载双击手势识别器
        if (!hasDoubleTap) {
            UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleNavBarDoubleTap:)];
            doubleTap.numberOfTapsRequired = 2;
            [navBar addGestureRecognizer:doubleTap];
        }
    }
}

- (void)handleNavBarDoubleTap:(UITapGestureRecognizer *)sender {
    // 触发双击时，动态获取当前正显示在屏幕最顶层的控制器，并让其滚动到顶部
    if (self.navigationController) {
        [self.navigationController.topViewController scrollToTopAnimated:YES];
    } else {
        [self scrollToTopAnimated:YES];
    }
}

@end