//
//  PlayerEPGView+Scroll.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView.h"
#import "PlayerEPGDateBar.h"

// 在分类声明中遵循协议，并声明暴露方法
@interface PlayerEPGView (Scroll) <PlayerEPGDateBarDelegate, UIScrollViewDelegate>

- (void)scroll_scrollToCurrentProgram;
- (void)startAutoScrollTimer;
- (void)stopAutoScrollTimer;

@end