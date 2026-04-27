//
//  UITableView+EmptyState.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-28.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// [新增] 专门用于处理 UITableView 空数据提示状态的通用分类
@interface UITableView (EmptyState)

/**
 * 显示空白提示视图
 * @param text 需要显示的提示文字
 */
- (void)showEmptyStateWithText:(NSString *)text;

/**
 * 隐藏空白提示视图并恢复默认的分割线样式
 */
- (void)hideEmptyState;

@end