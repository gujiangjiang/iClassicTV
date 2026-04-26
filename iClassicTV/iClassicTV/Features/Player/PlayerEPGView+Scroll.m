//
//  PlayerEPGView+Scroll.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView+Scroll.h"
#import "PlayerEPGView+Internal.h"
#import "PlayerEPGView+Data.h"
#import "EPGManager.h"
#import "EPGProgram.h"

@implementation PlayerEPGView (Scroll)

#pragma mark - PlayerEPGDateBarDelegate

- (void)dateBar:(PlayerEPGDateBar *)dateBar didSelectDateAtIndex:(NSInteger)index {
    NSDate *tappedDate = self.availableDates[index];
    if ([self.selectedDate isEqualToDate:tappedDate]) return;
    
    self.selectedDate = tappedDate;
    [self.dateBar highlightDateButtonAtIndex:index animated:YES];
    
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
        [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
    } else {
        self.displayPrograms = self.groupedPrograms[self.selectedDate];
        [self.tableView reloadData];
        [self handleScrollAfterDataLoadForDate:self.selectedDate];
    }
    
    [self startAutoScrollTimer];
}

- (void)dateBarWillBeginDragging:(PlayerEPGDateBar *)dateBar {
    [self stopAutoScrollTimer];
}

- (void)dateBarDidEndDragging:(PlayerEPGDateBar *)dateBar willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self startAutoScrollTimer];
}

- (void)dateBarDidEndDecelerating:(PlayerEPGDateBar *)dateBar {
    [self startAutoScrollTimer];
}

#pragma mark - Auto Scroll

- (void)startAutoScrollTimer {
    [self stopAutoScrollTimer];
    NSInteger timeout = [EPGManager sharedManager].autoScrollTimeout;
    if (timeout > 0) {
        self.autoScrollTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(autoScrollTimerFired) userInfo:nil repeats:NO];
    }
}

- (void)stopAutoScrollTimer {
    if (self.autoScrollTimer) {
        [self.autoScrollTimer invalidate];
        self.autoScrollTimer = nil;
    }
}

- (void)autoScrollTimerFired {
    if (self.availableDates.count == 0) return;
    
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    NSDate *targetDate = self.replayingProgram ? [self startOfDayForDate:self.replayingProgram.startTime] : todayStart;
    
    if (![self.selectedDate isEqualToDate:targetDate]) {
        NSUInteger index = [self.availableDates indexOfObject:targetDate];
        if (index != NSNotFound) {
            self.selectedDate = targetDate;
            [self.dateBar highlightDateButtonAtIndex:index animated:YES];
            
            if ([[EPGManager sharedManager] isDynamicEPGSource]) {
                NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
                [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
                return;
            } else {
                self.displayPrograms = self.groupedPrograms[self.selectedDate];
                [self.tableView reloadData];
                [self scrollToCurrentProgram];
            }
        }
    } else {
        [self scrollToCurrentProgram];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopAutoScrollTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self startAutoScrollTimer];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self startAutoScrollTimer];
}

- (void)scroll_scrollToCurrentProgram {
    if (self.displayPrograms.count == 0 || !self.selectedDate) return;
    
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    
    if (self.replayingProgram) {
        NSDate *replayDayStart = [self startOfDayForDate:self.replayingProgram.startTime];
        if (![self.selectedDate isEqualToDate:replayDayStart]) return;
        
        NSInteger currentIndex = -1;
        for (NSInteger i = 0; i < self.displayPrograms.count; i++) {
            EPGProgram *p = self.displayPrograms[i];
            if ([p.startTime isEqualToDate:self.replayingProgram.startTime]) {
                currentIndex = i;
                break;
            }
        }
        if (currentIndex >= 0 && currentIndex < self.displayPrograms.count) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        }
        return;
    }
    
    if (![self.selectedDate isEqualToDate:todayStart]) return;
    
    NSInteger currentIndex = -1;
    for (NSInteger i = 0; i < self.displayPrograms.count; i++) {
        EPGProgram *p = self.displayPrograms[i];
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            currentIndex = i;
            break;
        }
    }
    
    if (currentIndex >= 0 && currentIndex < self.displayPrograms.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

@end