//
//  UITableView+EmptyState.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-28.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UITableView+EmptyState.h"

@implementation UITableView (EmptyState)

- (void)showEmptyStateWithText:(NSString *)text {
    UILabel *emptyLabel = [[UILabel alloc] initWithFrame:self.bounds];
    emptyLabel.text = text;
    emptyLabel.textColor = [UIColor grayColor];
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.font = [UIFont systemFontOfSize:16.0f];
    emptyLabel.numberOfLines = 0;
    emptyLabel.backgroundColor = [UIColor clearColor];
    
    self.backgroundView = emptyLabel;
    self.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)hideEmptyState {
    self.backgroundView = nil;
    self.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

@end