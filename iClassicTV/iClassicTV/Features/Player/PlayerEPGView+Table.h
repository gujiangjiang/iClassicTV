//
//  PlayerEPGView+Table.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView.h"
#import <UIKit/UIKit.h>

// 在分类声明中遵循协议，避免主类指派 delegate 时警告
@interface PlayerEPGView (Table) <UITableViewDelegate, UITableViewDataSource>

@end