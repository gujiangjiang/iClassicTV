//
//  PlayerEPGView+Table.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView+Table.h"
#import "PlayerEPGView+Internal.h"
#import "PlayerEPGView+Scroll.h"
#import "EPGProgramCell.h"
#import "EPGProgram.h"
#import "LanguageManager.h"

@implementation PlayerEPGView (Table)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayPrograms.count;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[EPGProgramCell class]]) {
        [((EPGProgramCell *)cell).titleMarqueeLabel startAnimation];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"EPGProgramCellId";
    EPGProgramCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[EPGProgramCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSString *timeString = [self.timeFormatter stringFromDate:program.startTime];
    
    cell.timeLabel.text = timeString;
    cell.titleMarqueeLabel.text = program.title;
    
    NSDate *now = [NSDate date];
    
    BOOL isReplayingThis = (self.replayingProgram && [program.startTime isEqualToDate:self.replayingProgram.startTime]);
    BOOL isCurrentlyLive = ([now compare:program.startTime] != NSOrderedAscending && [now compare:program.endTime] == NSOrderedAscending);
    
    if (!self.isIOS7) {
        UIColor *shadowColor = [UIColor whiteColor];
        CGSize shadowOffset = CGSizeMake(0, 1);
        
        cell.timeLabel.shadowColor = shadowColor;
        cell.timeLabel.shadowOffset = shadowOffset;
        cell.titleMarqueeLabel.shadowColor = shadowColor;
        cell.titleMarqueeLabel.shadowOffset = shadowOffset;
        cell.statusLabel.shadowColor = shadowColor;
        cell.statusLabel.shadowOffset = shadowOffset;
    } else {
        cell.timeLabel.shadowColor = nil;
        cell.titleMarqueeLabel.shadowColor = nil;
        cell.statusLabel.shadowColor = nil;
    }
    
    UIFont *normalFont = [UIFont systemFontOfSize:14];
    UIFont *statusNormalFont = [UIFont systemFontOfSize:12];
    UIFont *boldFont = [UIFont boldSystemFontOfSize:15];
    
    if (isReplayingThis) {
        UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
        cell.timeLabel.textColor = themeColor;
        cell.titleMarqueeLabel.textColor = themeColor;
        cell.statusLabel.textColor = themeColor;
        cell.statusLabel.text = LocalizedString(@"now_replaying");
        cell.timeLabel.font = boldFont;
        cell.titleMarqueeLabel.font = boldFont;
        cell.statusLabel.font = statusNormalFont;
    } else if (isCurrentlyLive) {
        if (self.replayingProgram != nil) {
            UIColor *grayColor = [UIColor darkGrayColor];
            cell.timeLabel.textColor = grayColor;
            cell.titleMarqueeLabel.textColor = grayColor;
            cell.statusLabel.textColor = grayColor;
            cell.statusLabel.text = LocalizedString(@"playback_paused");
            cell.timeLabel.font = normalFont;
            cell.titleMarqueeLabel.font = normalFont;
            cell.statusLabel.font = statusNormalFont;
        } else {
            UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
            cell.timeLabel.textColor = themeColor;
            cell.titleMarqueeLabel.textColor = themeColor;
            cell.statusLabel.textColor = themeColor;
            cell.statusLabel.text = LocalizedString(@"now_playing");
            cell.timeLabel.font = boldFont;
            cell.titleMarqueeLabel.font = boldFont;
            cell.statusLabel.font = statusNormalFont;
        }
    } else if ([now compare:program.endTime] != NSOrderedAscending) {
        UIColor *grayColor = [UIColor darkGrayColor];
        cell.timeLabel.textColor = grayColor;
        cell.titleMarqueeLabel.textColor = grayColor;
        cell.statusLabel.textColor = grayColor;
        cell.statusLabel.text = LocalizedString(@"already_played");
        cell.timeLabel.font = normalFont;
        cell.titleMarqueeLabel.font = normalFont;
        cell.statusLabel.font = statusNormalFont;
    } else {
        UIColor *normalColor = [UIColor blackColor];
        cell.timeLabel.textColor = normalColor;
        cell.titleMarqueeLabel.textColor = normalColor;
        cell.statusLabel.textColor = normalColor;
        cell.statusLabel.text = LocalizedString(@"not_played");
        cell.timeLabel.font = normalFont;
        cell.titleMarqueeLabel.font = normalFont;
        cell.statusLabel.font = statusNormalFont;
    }
    
    if (self.supportsCatchup && ([now compare:program.startTime] != NSOrderedAscending)) {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.supportsCatchup) return;
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSDate *now = [NSDate date];
    if ([now compare:program.startTime] != NSOrderedAscending) {
        if ([self.delegate respondsToSelector:@selector(epgView:didSelectProgram:)]) {
            [self.delegate epgView:self didSelectProgram:program];
        }
        [self startAutoScrollTimer];
    }
}

@end