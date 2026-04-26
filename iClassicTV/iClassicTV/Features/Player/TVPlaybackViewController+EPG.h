//
//  TVPlaybackViewController+EPG.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController.h"
#import "PlayerEPGView.h"

// [修复] 将 EPG 视图的代理协议声明在这里，由 EPG 分类来实现
@interface TVPlaybackViewController (EPG) <PlayerEPGViewDelegate>

- (void)epgDataDidUpdateInBackground;
- (void)updateFullscreenEPGOverlay;

@end