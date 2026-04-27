//
//  TVPlaybackViewController+Player.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController+Player.h"
#import "TVPlaybackViewController+Internal.h"
#import "TVPlaybackViewController+UI.h"
#import "TVPlaybackViewController+EPG.h"
#import "LanguageManager.h"
#import "PlayerConfigManager.h"

// [新增] 引入网络流量计算所需底层 C 语言库
#include <ifaddrs.h>
#include <net/if.h>
#include <sys/socket.h>

@implementation TVPlaybackViewController (Player)

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) [self.player play];
        else if (event.subtype == UIEventSubtypeRemoteControlPause) [self.player pause];
        else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            if (self.player.playbackState == MPMoviePlaybackStatePlaying) [self.player pause];
            else [self.player play];
        }
    }
}

- (void)updateNowPlayingInfo {
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        [info setObject:(self.channelTitle ?: LocalizedString(@"unknown_channel")) forKey:MPMediaItemPropertyTitle];
        if (self.channelLogo) {
            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:self.channelLogo];
            [info setObject:artwork forKey:MPMediaItemPropertyArtwork];
        }
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
    }
}

- (void)loadStateChanged {
    if (self.player.loadState & MPMovieLoadStateStalled) [self.overlayView showStatusMessage:LocalizedString(@"buffering")];
    else if ((self.player.loadState & MPMovieLoadStatePlayable) || (self.player.loadState & MPMovieLoadStatePlaythroughOK)) {
        if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
            [self.overlayView showStatusMessage:LocalizedString(@"audio_only_signal")];
        } else [self.overlayView hideStatusMessage];
    }
}

- (void)mediaTypesAvailable {
    if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) == 0 && (self.player.movieMediaTypes & MPMovieMediaTypeMaskAudio) != 0) {
        [self.overlayView showStatusMessage:LocalizedString(@"audio_only_signal")];
    } else if ((self.player.movieMediaTypes & MPMovieMediaTypeMaskVideo) != 0) {
        if (self.player.loadState & MPMovieLoadStatePlayable || self.player.loadState & MPMovieLoadStatePlaythroughOK) {
            [self.overlayView hideStatusMessage];
        }
    }
}

- (void)playbackStateChanged {
    [self.overlayView.bottomBar updatePlayButtonState:(self.player.playbackState == MPMoviePlaybackStatePlaying)];
}

- (void)playbackDidFinish:(NSNotification *)notification {
    NSNumber *reason = [notification.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if (reason != nil && [reason integerValue] == MPMovieFinishReasonPlaybackError) {
        [self.overlayView showStatusMessage:LocalizedString(@"playback_failed")];
    }
}

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
}

// [新增] 获取系统所有网卡当前的总下行字节数
- (long long)getInterfaceBytes {
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1) return 0;
    long long ibytes = 0;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family) continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING)) continue;
        if (ifa->ifa_data == 0) continue;
        
        // 排除本地回环网卡(lo0)产生的数据，确保仅计算外网流量
        if (strncmp(ifa->ifa_name, "lo", 2) == 0) continue;
        
        struct if_data *if_data = (struct if_data *)ifa->ifa_data;
        ibytes += if_data->ifi_ibytes;
    }
    freeifaddrs(ifa_list);
    return ibytes;
}

- (void)updateProgress {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        [self.overlayView.bottomBar updateProgressWithValue:(self.player.currentPlaybackTime / self.player.duration)];
    }
    [self.epgView updateTimeTick];
    [self updateFullscreenEPGOverlay];
    [self.overlayView.widgetsView updateSystemTime];
    
    // [新增] 动态网速计算逻辑（仅当配置开启且处于全屏时计算并更新 UI）
    if ([PlayerConfigManager showNetworkSpeedInFullscreen] && self.isFullscreen) {
        long long currentBytes = [self getInterfaceBytes];
        if (self.lastNetworkBytes > 0) {
            long long diff = currentBytes - self.lastNetworkBytes;
            if (diff < 0) diff = 0; // 防护：处理网络切换等极端情况导致差值为负
            
            NSString *speedStr = @"";
            if (diff < 1024) {
                speedStr = [NSString stringWithFormat:@"%lld B/s", diff];
            } else if (diff < 1024 * 1024) {
                speedStr = [NSString stringWithFormat:@"%.1f KB/s", (double)diff / 1024.0];
            } else {
                speedStr = [NSString stringWithFormat:@"%.2f MB/s", (double)diff / (1024.0 * 1024.0)];
            }
            [self.overlayView.widgetsView updateNetworkSpeed:speedStr];
        }
        self.lastNetworkBytes = currentBytes;
    } else {
        // [新增] 不满足展示条件时清空数据并隐藏 UI
        [self.overlayView.widgetsView updateNetworkSpeed:nil];
    }
}

#pragma mark - TVPlaybackOverlayDelegate

- (void)overlayDidTapPlayPause {
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) [self.player pause];
    else [self.player play];
}

- (void)overlayDidTapFullscreen {
    if (self.isFullscreen) {
        // 用户主动退出全屏时，清除“手动全屏”记忆标记
        self.isManualFullscreen = NO;
        
        // 如果当前是物理上的横屏，退出全屏必须将其旋转回竖屏
        if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
            // 先标记退出全屏，这样旋转动画开始时，UI 就会提前判定为退出全屏状态
            self.isFullscreen = NO;
            [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
        } else {
            // 如果是竖屏全屏模式，直接修改全屏标记并刷新UI即可
            self.isFullscreen = NO;
            [self updateFullscreenUIState];
        }
    } else {
        // 准备进入全屏：只要是手动点击进入，就开启“手动全屏”记忆标记
        self.isFullscreen = YES;
        self.isManualFullscreen = YES;
        
        // 直接读取设置中的枚举值，彻底修复“跟随系统”失效总是横屏的 Bug
        NSInteger pref = [PlayerConfigManager preferredInterfaceOrientationPref];
        
        if (pref == 1) { // 设置项要求强制横屏
            if (!UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
                [self forceRotateToOrientation:UIInterfaceOrientationLandscapeRight];
            } else {
                [self updateFullscreenUIState];
            }
        } else if (pref == 2) { // 设置项要求强制竖屏
            if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
                [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
            } else {
                [self updateFullscreenUIState];
            }
        } else { // 设置项要求跟随系统 (0)
            // 直接在当前方向上进入全屏界面模式（不强制旋转设备）
            [self updateFullscreenUIState];
        }
    }
}

- (void)overlaySliderValueChanged:(float)value {
    if (self.player.duration > 0 && !isnan(self.player.duration)) {
        self.player.currentPlaybackTime = value * self.player.duration;
    }
}

- (void)overlayControlsHiddenDidChange:(BOOL)isHidden {
    self.isControlsHidden = isHidden;
    
    BOOL isLocked = self.overlayView.isLocked;
    
    // 无论是竖向全屏还是横向全屏，只要是在全屏模式，控件显隐或锁定状态就决定状态栏的显隐
    BOOL shouldHideStatusBar = self.isFullscreen ? (isHidden || isLocked) : NO;
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationFade];
    }
    
    if (isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        
        // 锁屏状态下，强制隐藏所有的挂件（节目单、时间等）
        [UIView animateWithDuration:0.25 animations:^{
            [self.overlayView.widgetsView setOverlaysHidden:YES];
        }];
    } else {
        BOOL shouldHideNav = self.isFullscreen ? isHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHideNav animated:YES];
        
        // [修复] 非锁屏状态下，挂件显隐状态彻底与播放控件栏的显隐保持同步
        [UIView animateWithDuration:0.25 animations:^{
            [self.overlayView.widgetsView setOverlaysHidden:(self.isFullscreen ? isHidden : NO)];
        }];
        
        // 手动调整 iOS 6 下导航条出现时的 Y 轴偏移，防止被悬浮的半透明状态栏遮盖
        if (![[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0 && !shouldHideNav) {
            CGRect navFrame = self.navigationController.navigationBar.frame;
            CGFloat expectedY = shouldHideStatusBar ? 0.0 : 20.0;
            if (navFrame.origin.y != expectedY) {
                navFrame.origin.y = expectedY;
                self.navigationController.navigationBar.frame = navFrame;
            }
        }
    }
}

@end