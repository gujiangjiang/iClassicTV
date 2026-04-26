//
//  TVPlaybackViewController+EPG.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVPlaybackViewController+EPG.h"
#import "TVPlaybackViewController+Internal.h"
#import "EPGManager.h"
#import "EPGManagerViewController.h"
#import "ToastHelper.h"
#import "LanguageManager.h"
#import "NSString+EncodingHelper.h"

@implementation TVPlaybackViewController (EPG)

// [新增] EPG 数据后台刷新完成后的 UI 更新回调
- (void)epgDataDidUpdateInBackground {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.epgView reloadData];
        [self updateFullscreenEPGOverlay];
    });
}

#pragma mark - PlayerEPGViewDelegate

- (void)epgViewDidTapSettings:(PlayerEPGView *)epgView {
    EPGManagerViewController *epgVC = [[EPGManagerViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:epgVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)epgViewDidTapRefresh:(PlayerEPGView *)epgView {
    [ToastHelper showToastWithMessage:LocalizedString(@"epg_updating_silently")];
    [[EPGManager sharedManager] fetchAndParseEPGDataWithCompletion:^(BOOL success, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [ToastHelper showToastWithMessage:LocalizedString(@"epg_update_complete")];
            } else {
                [ToastHelper showToastWithMessage:[NSString stringWithFormat:LocalizedString(@"epg_update_failed_msg"), errorMsg]];
            }
        });
    }];
}

- (void)epgView:(PlayerEPGView *)epgView didSelectProgram:(EPGProgram *)program {
    if (self.catchupSource.length == 0) return;
    
    NSDate *now = [NSDate date];
    
    if ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending) {
        self.replayingProgram = nil;
        self.epgView.replayingProgram = nil;
        self.overlayView.widgetsView.isCatchupMode = NO;
        
        NSURL *url = [self.videoURLString toSafeURL];
        
        [self.player setContentURL:url];
        [self.player play];
        
        [self.overlayView showStatusMessage:[NSString stringWithFormat:LocalizedString(@"returned_to_live_format"), program.title]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.overlayView hideStatusMessage];
        });
        
        [self updateFullscreenEPGOverlay];
        return;
    }
    
    self.replayingProgram = program;
    self.epgView.replayingProgram = program;
    self.overlayView.widgetsView.isCatchupMode = YES;
    
    NSString *bTime = [self.catchupTimeFormatter stringFromDate:program.startTime];
    NSString *eTime = [self.catchupTimeFormatter stringFromDate:program.endTime];
    
    NSString *catchupParams = self.catchupSource;
    catchupParams = [catchupParams stringByReplacingOccurrencesOfString:@"${(b)yyyyMMddHHmmss}" withString:bTime];
    catchupParams = [catchupParams stringByReplacingOccurrencesOfString:@"${(e)yyyyMMddHHmmss}" withString:eTime];
    
    NSString *finalURLStr = self.videoURLString;
    if ([catchupParams hasPrefix:@"http://"] || [catchupParams hasPrefix:@"https://"]) {
        finalURLStr = catchupParams;
    } else {
        finalURLStr = [finalURLStr stringByAppendingString:catchupParams];
    }
    
    NSURL *url = [finalURLStr toSafeURL];
    
    [self.player setContentURL:url];
    [self.player play];
    
    NSString *displayTime = [self.displayTimeFormatter stringFromDate:program.startTime];
    
    // [优化] 提示语改成多行显示：第一行正在回放，第二行显示日期+时间，第三行显示节目名
    NSString *multiLineMsg = [NSString stringWithFormat:@"正在回放\n%@\n%@", displayTime, program.title];
    [self.overlayView showStatusMessage:multiLineMsg];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.overlayView hideStatusMessage];
    });
    
    [self updateFullscreenEPGOverlay];
}

// [新增] 专门用于提取多语言前缀（如“正在播放：”）并强制按照 “状态 时间 \t 片名” 重组字符串，以实现自定义完美排版
- (NSString *)generateProgramTextWithKey:(NSString *)key program:(EPGProgram *)program {
    if (!program) return nil;
    NSString *timeStr = [self.epgTimeFormatter stringFromDate:program.startTime];
    NSString *format = LocalizedString(key);
    // 通过传入空字符串，把 "%@ 正在播放：%@" 这样的多语言原文提取成 " 正在播放： "，再清理掉多余的空格
    NSString *staticPart = [[NSString stringWithFormat:format, @"", @""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    // 如果翻译是以全角冒号结尾的，后面就不额外加空格了，否则加一个空格更美观
    NSString *space = [staticPart hasSuffix:@"："] ? @"" : @" ";
    // \t 是关键标记，UI层会识别它来进行竖屏换行或横屏空格的替换
    return [NSString stringWithFormat:@"%@%@%@\t%@", staticPart, space, timeStr, program.title];
}

- (void)updateFullscreenEPGOverlay {
    if (![EPGManager sharedManager].isEPGEnabled || !self.isFullscreen) {
        return;
    }
    
    EPGProgram *current = [self.epgView currentPlayingProgram];
    
    if (self.replayingProgram) {
        NSString *line1 = [self generateProgramTextWithKey:@"replaying_colon_format" program:self.replayingProgram];
        NSString *line2 = current ? [self generateProgramTextWithKey:@"live_colon_format" program:current] : LocalizedString(@"live_no_data");
        [self.overlayView.widgetsView updateCurrentProgram:line1 nextProgram:line2];
    } else {
        EPGProgram *next = [self.epgView nextPlayingProgram];
        if (!current && !next) {
            [self.overlayView.widgetsView updateCurrentProgram:nil nextProgram:nil];
            return;
        }
        
        NSString *currentStr = current ? [self generateProgramTextWithKey:@"playing_colon_format" program:current] : LocalizedString(@"playing_no_data");
        NSString *nextStr = next ? [self generateProgramTextWithKey:@"next_colon_format" program:next] : LocalizedString(@"next_no_data");
        [self.overlayView.widgetsView updateCurrentProgram:currentStr nextProgram:nextStr];
    }
}

@end