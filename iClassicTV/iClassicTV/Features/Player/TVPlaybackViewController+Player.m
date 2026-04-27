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
    // [优化] 调用 overlayView 统一更新播放状态，它会负责同步中央大按钮和底栏控件，并执行动画
    [self.overlayView updatePlaybackState:(self.player.playbackState == MPMoviePlaybackStatePlaying)];
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

- (long long)getInterfaceBytes {
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1) return 0;
    long long ibytes = 0;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family) continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING)) continue;
        if (ifa->ifa_data == 0) continue;
        
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
    
    if ([PlayerConfigManager showNetworkSpeedInFullscreen] && self.isFullscreen) {
        long long currentBytes = [self getInterfaceBytes];
        if (self.lastNetworkBytes > 0) {
            long long diff = currentBytes - self.lastNetworkBytes;
            if (diff < 0) diff = 0;
            
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
        self.isManualFullscreen = NO;
        if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
            self.isFullscreen = NO;
            [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
        } else {
            self.isFullscreen = NO;
            [self updateFullscreenUIState];
        }
    } else {
        self.isFullscreen = YES;
        self.isManualFullscreen = YES;
        
        NSInteger pref = [PlayerConfigManager preferredInterfaceOrientationPref];
        
        if (pref == 1) {
            if (!UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
                [self forceRotateToOrientation:UIInterfaceOrientationLandscapeRight];
            } else {
                [self updateFullscreenUIState];
            }
        } else if (pref == 2) {
            if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
                [self forceRotateToOrientation:UIInterfaceOrientationPortrait];
            } else {
                [self updateFullscreenUIState];
            }
        } else {
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
    BOOL shouldHideStatusBar = self.isFullscreen ? (isHidden || isLocked) : NO;
    
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:shouldHideStatusBar withAnimation:UIStatusBarAnimationFade];
    }
    
    if (isLocked) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        
        [UIView animateWithDuration:0.25 animations:^{
            [self.overlayView.widgetsView setOverlaysHidden:YES];
        }];
    } else {
        BOOL shouldHideNav = self.isFullscreen ? isHidden : NO;
        [self.navigationController setNavigationBarHidden:shouldHideNav animated:YES];
        
        [UIView animateWithDuration:0.25 animations:^{
            [self.overlayView.widgetsView setOverlaysHidden:(self.isFullscreen ? isHidden : NO)];
        }];
        
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