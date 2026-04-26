//
//  TVPlaybackViewController+Internal.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "TVPlaybackOverlayView.h"
#import "PlayerEPGView.h"
#import "EPGProgram.h"

// 声明所有原本在 .m 中的私有属性，使得各分类都能访问
// [修复] 移除了这里的 Delegate 声明，防止主类 .m 文件报未实现的警告
@interface TVPlaybackViewController ()

@property (nonatomic, strong) MPMoviePlayerController *player;
@property (nonatomic, strong) TVPlaybackOverlayView *overlayView;

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *epgContainerView;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, assign) BOOL isManualFullscreen;
@property (nonatomic, assign) BOOL isControlsHidden;

@property (nonatomic, strong) PlayerEPGView *epgView;
@property (nonatomic, strong) NSDateFormatter *epgTimeFormatter;
@property (nonatomic, strong) NSDateFormatter *catchupTimeFormatter;
@property (nonatomic, strong) NSDateFormatter *displayTimeFormatter;

@property (nonatomic, strong) EPGProgram *replayingProgram;

@property (nonatomic, assign) UIBarStyle originalBarStyle;
@property (nonatomic, assign) BOOL originalTranslucent;
@property (nonatomic, assign) UIStatusBarStyle originalStatusBarStyle;
@property (nonatomic, assign) BOOL hasSavedOriginalNavState;

@end