//
//  TVPlaybackViewController+Player.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController.h"
#import "TVPlaybackOverlayView.h"

@interface TVPlaybackViewController (Player) <TVPlaybackOverlayDelegate>

- (void)startTimer;
- (void)updateNowPlayingInfo;

// [修复] 补充声明这 4 个通知回调方法，消除主文件中的 Undeclared selector 警告
- (void)playbackStateChanged;
- (void)loadStateChanged;
- (void)mediaTypesAvailable;
- (void)playbackDidFinish:(NSNotification *)notification;

@end