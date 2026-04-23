//
//  AboutViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "AboutViewController.h"

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"关于";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    // 修复：将固定的高度 250 改为自适应当前视图高度，防止在小屏幕设备（如 iPhone 4/4s）上文字被截断
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, self.view.bounds.size.height - 40)];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 增加自动拉伸属性，适配屏幕尺寸变化
    textView.backgroundColor = [UIColor clearColor];
    textView.editable = NO;
    textView.font = [UIFont systemFontOfSize:15];
    textView.text = @"iClassicTV (Native iOS 6 Edition)\n\n一款专为怀旧党和老旧 iOS 设备（如 iPhone 4/4s、iPad 2/3）打造的纯原生 IPTV / M3U 直播源播放器。\n\n• 纯正拟物化 UI\n• 硬件级解码播放\n• 智能多线路记忆\n• 强大的多源管理\n\n版本: 1.0\n作者: gujiangjiang\n开源协议: MIT License";
    [self.view addSubview:textView];
}

@end