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
#import <objc/runtime.h>
#import "WatchListDataManager.h"
#import "ToastHelper.h"

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
        // [优化] 未来未播放的节目，先判断是否已经处于预约状态
        NSString *channelName = LocalizedString(@"unknown_channel");
        NSArray *recentPlays = [[WatchListDataManager sharedManager] getRecentPlays];
        if (recentPlays.count > 0) {
            channelName = recentPlays.firstObject[@"name"] ?: recentPlays.firstObject[@"title"];
            if (!channelName) channelName = LocalizedString(@"unknown_channel");
        }
        
        if ([[WatchListDataManager sharedManager] isAppointed:channelName startTime:program.startTime]) {
            // 已预约的颜色稍微做个区分（例如使用主题色来提示活跃状态），或者也可以用默认黑色
            UIColor *themeColor = self.isIOS7 ? [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0] : [UIColor orangeColor];
            cell.timeLabel.textColor = themeColor;
            cell.titleMarqueeLabel.textColor = themeColor;
            cell.statusLabel.textColor = themeColor;
            cell.statusLabel.text = LocalizedString(@"already_reserved");
        } else {
            UIColor *normalColor = [UIColor blackColor];
            cell.timeLabel.textColor = normalColor;
            cell.titleMarqueeLabel.textColor = normalColor;
            cell.statusLabel.textColor = normalColor;
            cell.statusLabel.text = LocalizedString(@"not_played");
        }
        
        cell.timeLabel.font = normalFont;
        cell.titleMarqueeLabel.font = normalFont;
        cell.statusLabel.font = statusNormalFont;
    }
    
    // 未来的节目也允许点击，用来触发预约操作
    if ((self.supportsCatchup && ([now compare:program.startTime] != NSOrderedAscending)) || ([now compare:program.startTime] == NSOrderedAscending)) {
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
    
    EPGProgram *program = self.displayPrograms[indexPath.row];
    NSDate *now = [NSDate date];
    
    if ([now compare:program.startTime] != NSOrderedAscending) {
        // 播放支持回放的过去节目
        if (!self.supportsCatchup) return;
        if ([self.delegate respondsToSelector:@selector(epgView:didSelectProgram:)]) {
            [self.delegate epgView:self didSelectProgram:program];
        }
        [self startAutoScrollTimer];
    } else {
        // 触发未来节目的预约/取消预约功能
        NSString *channelName = LocalizedString(@"unknown_channel");
        NSArray *recentPlays = [[WatchListDataManager sharedManager] getRecentPlays];
        if (recentPlays.count > 0) {
            channelName = recentPlays.firstObject[@"name"] ?: recentPlays.firstObject[@"title"];
            if (!channelName) channelName = LocalizedString(@"unknown_channel");
        }
        
        // 检查是否已经预约
        if ([[WatchListDataManager sharedManager] isAppointed:channelName startTime:program.startTime]) {
            // [修改] 已预约的情况下，弹出取消预约确认框
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"MM-dd HH:mm"];
            NSString *timeStr = [df stringFromDate:program.startTime];
            
            NSString *msg = [NSString stringWithFormat:LocalizedString(@"cancel_reserve_msg_format"), channelName, timeStr, program.title];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"cancel_reserve_title") message:msg delegate:self cancelButtonTitle:LocalizedString(@"reserve_cancel") otherButtonTitles:LocalizedString(@"cancel_reserve_confirm"), nil];
            alert.tag = 2; // 标识为取消预约
            // 绑定数据到 UIAlertView，用于回调时提取
            objc_setAssociatedObject(alert, "EPGProgramKey", program, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(alert, "ChannelNameKey", channelName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [alert show];
        } else {
            // 格式化具体的日期时间和弹窗消息
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"MM-dd HH:mm"];
            NSString *timeStr = [df stringFromDate:program.startTime];
            
            NSString *msg = [NSString stringWithFormat:LocalizedString(@"reserve_program_msg_format"), channelName, timeStr, program.title];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LocalizedString(@"reserve_program_title") message:msg delegate:self cancelButtonTitle:LocalizedString(@"reserve_cancel") otherButtonTitles:LocalizedString(@"reserve_confirm"), nil];
            alert.tag = 1; // 标识为新增预约
            // 绑定数据到 UIAlertView，用于回调时提取
            objc_setAssociatedObject(alert, "EPGProgramKey", program, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(alert, "ChannelNameKey", channelName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [alert show];
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // 点击了确认按钮（包括确认预约或确认取消预约）
        EPGProgram *program = objc_getAssociatedObject(alertView, "EPGProgramKey");
        NSString *channelName = objc_getAssociatedObject(alertView, "ChannelNameKey");
        if (program && channelName) {
            if (alertView.tag == 2) {
                // [新增] 取消预约逻辑
                NSDictionary *appointmentInfo = @{
                                                  @"channelName": channelName,
                                                  @"startTime": program.startTime
                                                  };
                [[WatchListDataManager sharedManager] removeAppointment:appointmentInfo];
                
                [ToastHelper showToastWithMessage:LocalizedString(@"cancel_reserve_success")];
            } else {
                // [原有] 新增预约逻辑
                // [修复] 补充完整的链接参数，确保特定URL记录模式能够正常跳转
                NSDictionary *appointmentInfo = @{
                                                  @"channelName": channelName,
                                                  @"url": self.videoURLString ?: @"",
                                                  @"tvgName": self.tvgName ?: @"",
                                                  @"catchupSource": self.catchupSource ?: @"",
                                                  @"title": program.title,
                                                  @"startTime": program.startTime,
                                                  @"endTime": program.endTime
                                                  };
                [[WatchListDataManager sharedManager] addAppointment:appointmentInfo];
                
                // [优化] 将成功弹窗替换为 Toast 提示，提升用户体验
                [ToastHelper showToastWithMessage:LocalizedString(@"reserve_success")];
            }
            
            // 刷新当前表格，使刚才点击的节目立刻显示最新状态
            if ([self respondsToSelector:@selector(tableView)]) {
                UITableView *tv = [self performSelector:@selector(tableView)];
                if (tv) {
                    [tv reloadData];
                }
            }
        }
    }
}

@end