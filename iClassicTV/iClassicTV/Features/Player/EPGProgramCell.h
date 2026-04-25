//
//  EPGProgramCell.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 独立出的跑马灯 Label 组件
@interface EPGMarqueeLabel : UIView
@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, assign) CGSize shadowOffset;
- (void)startAnimation;
@end

// 独立出的节目列表 Cell
@interface EPGProgramCell : UITableViewCell
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) EPGMarqueeLabel *titleMarqueeLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@end