//
//  PlayerEPGEmptyView.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGEmptyView.h"
#import "LanguageManager.h"

@interface PlayerEPGEmptyView ()
@property (nonatomic, strong) UILabel *emptyIconLabel;
@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, assign) BOOL isIOS7;
@end

@implementation PlayerEPGEmptyView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        
        self.emptyIconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.emptyIconLabel.backgroundColor = [UIColor clearColor];
        self.emptyIconLabel.textAlignment = NSTextAlignmentCenter;
        self.emptyIconLabel.font = [UIFont systemFontOfSize:50];
        [self addSubview:self.emptyIconLabel];
        
        self.tipsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.tipsLabel.backgroundColor = [UIColor clearColor];
        self.tipsLabel.textAlignment = NSTextAlignmentCenter;
        self.tipsLabel.textColor = [UIColor darkGrayColor];
        self.tipsLabel.font = [UIFont systemFontOfSize:15];
        self.tipsLabel.numberOfLines = 0;
        [self addSubview:self.tipsLabel];
        
        self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        [self.actionButton setTitleColor:themeColor forState:UIControlStateNormal];
        self.actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        self.actionButton.layer.borderColor = themeColor.CGColor;
        self.actionButton.layer.borderWidth = 1.0;
        self.actionButton.layer.cornerRadius = 16.0;
        self.actionButton.layer.masksToBounds = YES;
        self.actionButton.hidden = YES;
        [self.actionButton addTarget:self action:@selector(actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.actionButton];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat containerWidth = self.bounds.size.width;
    CGFloat containerHeight = self.bounds.size.height;
    
    // 垂直居中排版
    self.emptyIconLabel.frame = CGRectMake(0, containerHeight / 2.0 - 70, containerWidth, 60);
    self.tipsLabel.frame = CGRectMake(20, containerHeight / 2.0 - 5, containerWidth - 40, 40);
    self.actionButton.frame = CGRectMake((containerWidth - 120) / 2.0, containerHeight / 2.0 + 45, 120, 32);
}

- (void)setState:(EPGEmptyStateType)state {
    // 无论什么状态，如果有数据(None状态)则隐藏整个空视图，否则显示
    self.hidden = (state == EPGEmptyStateTypeNone);
    
    // 修复警告：将 None 状态放入 switch 语句中，彻底覆盖所有枚举分支
    switch (state) {
        case EPGEmptyStateTypeNone:
            // 隐藏状态，无需做任何 UI 赋值操作
            break;
        case EPGEmptyStateTypeNotEnabled:
            self.emptyIconLabel.text = @"📺";
            self.tipsLabel.text = LocalizedString(@"epg_not_enabled");
            [self.actionButton setTitle:LocalizedString(@"go_to_settings") forState:UIControlStateNormal];
            self.actionButton.tag = 1;
            self.actionButton.hidden = NO;
            break;
        case EPGEmptyStateTypeNoData:
            self.emptyIconLabel.text = @"📭";
            self.tipsLabel.text = LocalizedString(@"no_epg_data");
            self.actionButton.hidden = YES;
            break;
        case EPGEmptyStateTypeExpired:
            self.emptyIconLabel.text = @"⏳";
            self.tipsLabel.text = LocalizedString(@"epg_expired");
            [self.actionButton setTitle:LocalizedString(@"refresh_now") forState:UIControlStateNormal];
            self.actionButton.tag = 2;
            self.actionButton.hidden = NO;
            break;
        case EPGEmptyStateTypeLoading:
            self.emptyIconLabel.text = @"📡";
            self.tipsLabel.text = LocalizedString(@"loading");
            self.actionButton.hidden = YES;
            break;
    }
}

- (void)actionButtonTapped:(UIButton *)sender {
    if (sender.tag == 1 && [self.delegate respondsToSelector:@selector(emptyViewDidTapSettings)]) {
        [self.delegate emptyViewDidTapSettings];
    } else if (sender.tag == 2 && [self.delegate respondsToSelector:@selector(emptyViewDidTapRefresh)]) {
        [self.delegate emptyViewDidTapRefresh];
    }
}

@end