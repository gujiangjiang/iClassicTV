//
//  PlayerEPGView+Data.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView+Data.h"
#import "PlayerEPGView+Internal.h"
#import "PlayerEPGView+Scroll.h"
#import "EPGManager.h"
#import "EPGProgram.h"

@implementation PlayerEPGView (Data)

#pragma mark - PlayerEPGEmptyViewDelegate

- (void)emptyViewDidTapSettings {
    if ([self.delegate respondsToSelector:@selector(epgViewDidTapSettings:)]) {
        [self.delegate epgViewDidTapSettings:self];
    }
}

- (void)emptyViewDidTapRefresh {
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
        NSDate *targetDate = self.selectedDate ?: [self startOfDayForDate:[NSDate date]];
        
        if (self.groupedPrograms[targetDate]) {
            NSMutableDictionary *mut = [self.groupedPrograms mutableCopy];
            [mut removeObjectForKey:targetDate];
            self.groupedPrograms = mut;
        }
        
        [self fetchAndDisplayDynamicEPGForDate:targetDate channel:epgSearchName];
    } else {
        if ([self.delegate respondsToSelector:@selector(epgViewDidTapRefresh:)]) {
            [self.delegate epgViewDidTapRefresh:self];
        }
    }
}

#pragma mark - Data Loading

- (void)data_reloadData {
    BOOL isEPGEnabled = [EPGManager sharedManager].isEPGEnabled;
    NSString *epgSearchName = (self.tvgName && self.tvgName.length > 0) ? self.tvgName : self.channelTitle;
    
    self.emptyView.isDynamicSource = [[EPGManager sharedManager] isDynamicEPGSource];
    
    if (![self.currentChannelName isEqualToString:epgSearchName]) {
        self.currentChannelName = epgSearchName;
        self.availableDates = nil;
        self.groupedPrograms = nil;
        self.selectedDate = nil;
        self.lastPlayingProgram = nil;
        [self.dateBar resetScrollPosition];
        [self stopAutoScrollTimer];
    }
    
    if (!isEPGEnabled) {
        [self.emptyView setState:EPGEmptyStateTypeNotEnabled];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        [self.tableView reloadData];
        return;
    }
    
    if ([[EPGManager sharedManager] isDynamicEPGSource]) {
        self.dateBar.hidden = NO;
        self.separatorLine.hidden = NO;
        self.tableView.hidden = NO;
        
        if (!self.availableDates) {
            NSDate *today = [self startOfDayForDate:[NSDate date]];
            NSMutableArray *dates = [NSMutableArray array];
            for (int i = -5; i <= 1; i++) {
                [dates addObject:[today dateByAddingTimeInterval:i * 86400]];
            }
            self.availableDates = [dates copy];
            self.groupedPrograms = [NSMutableDictionary dictionary];
            [self.dateBar updateWithDates:self.availableDates];
            self.selectedDate = today;
            [self.dateBar highlightDateButtonAtIndex:5 animated:NO];
        }
        [self fetchAndDisplayDynamicEPGForDate:self.selectedDate channel:epgSearchName];
        return;
    }
    
    NSArray *allPrograms = @[];
    if (isEPGEnabled) {
        NSArray *fetched = [[EPGManager sharedManager] programsForChannelName:epgSearchName];
        if (fetched) allPrograms = fetched;
    }
    
    BOOL isExpired = YES;
    NSDate *now = [NSDate date];
    if (allPrograms.count > 0) {
        for (EPGProgram *p in allPrograms) {
            if ([p.endTime compare:now] == NSOrderedDescending) {
                isExpired = NO;
                break;
            }
        }
    }
    
    if (allPrograms.count == 0) {
        [self.emptyView setState:EPGEmptyStateTypeNoData];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    if (isExpired) {
        [self.emptyView setState:EPGEmptyStateTypeExpired];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.tableView reloadData];
        return;
    }
    
    self.dateBar.hidden = NO;
    self.separatorLine.hidden = NO;
    self.tableView.hidden = NO;
    
    NSMutableDictionary *grouped = [NSMutableDictionary dictionary];
    for (EPGProgram *p in allPrograms) {
        NSDate *dayStart = [self startOfDayForDate:p.startTime];
        NSMutableArray *dayPrograms = grouped[dayStart];
        if (!dayPrograms) {
            dayPrograms = [NSMutableArray array];
            grouped[(id<NSCopying>)dayStart] = dayPrograms;
        }
        [dayPrograms addObject:p];
    }
    self.groupedPrograms = grouped;
    self.availableDates = [[grouped allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    [self.dateBar updateWithDates:self.availableDates];
    
    if (self.availableDates.count > 0) {
        NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
        NSUInteger todayIndex = [self.availableDates indexOfObject:todayStart];
        if (todayIndex != NSNotFound) {
            self.selectedDate = todayStart;
            [self.dateBar highlightDateButtonAtIndex:todayIndex animated:NO];
        } else {
            self.selectedDate = self.availableDates.firstObject;
            [self.dateBar highlightDateButtonAtIndex:0 animated:NO];
        }
        self.displayPrograms = self.groupedPrograms[self.selectedDate];
        [self.emptyView setState:EPGEmptyStateTypeNone];
        self.tableView.hidden = NO;
    } else {
        self.displayPrograms = @[];
        self.selectedDate = nil;
        [self.emptyView setState:EPGEmptyStateTypeNoData];
        self.dateBar.hidden = YES;
        self.separatorLine.hidden = YES;
        self.tableView.hidden = YES;
    }
    
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollToCurrentProgram];
        [self startAutoScrollTimer];
    });
}

- (void)handleScrollAfterDataLoadForDate:(NSDate *)date {
    NSDate *targetDate = self.replayingProgram ? [self startOfDayForDate:self.replayingProgram.startTime] : [self startOfDayForDate:[NSDate date]];
    
    if ([date isEqualToDate:targetDate]) {
        [self scrollToCurrentProgram];
    } else {
        if (self.displayPrograms.count > 0) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
    }
}

- (void)fetchAndDisplayDynamicEPGForDate:(NSDate *)date channel:(NSString *)channelName {
    if (self.groupedPrograms[date]) {
        self.displayPrograms = self.groupedPrograms[date];
        if (self.displayPrograms.count > 0) {
            [self.emptyView setState:EPGEmptyStateTypeNone];
            self.tableView.hidden = NO;
        } else {
            [self.emptyView setState:EPGEmptyStateTypeNoData];
            self.tableView.hidden = YES;
        }
        [self.tableView reloadData];
        [self handleScrollAfterDataLoadForDate:date];
        [self startAutoScrollTimer];
    } else {
        self.displayPrograms = @[];
        [self.tableView reloadData];
        
        self.tableView.hidden = YES;
        [self.emptyView setState:EPGEmptyStateTypeLoading];
        
        __weak typeof(self) weakSelf = self;
        [[EPGManager sharedManager] fetchDynamicProgramsForChannelName:channelName date:date completion:^(NSArray *programs) {
            if ([weakSelf.currentChannelName isEqualToString:channelName] && [weakSelf.selectedDate isEqualToDate:date]) {
                
                NSArray *existingData = weakSelf.groupedPrograms[date];
                if ((!programs || programs.count == 0) && existingData && existingData.count > 0) {
                    weakSelf.displayPrograms = existingData;
                    [weakSelf.emptyView setState:EPGEmptyStateTypeNone];
                    weakSelf.tableView.hidden = NO;
                    [weakSelf.tableView reloadData];
                    return;
                }
                
                NSMutableDictionary *mut = [weakSelf.groupedPrograms mutableCopy] ?: [NSMutableDictionary dictionary];
                mut[date] = programs ?: @[];
                weakSelf.groupedPrograms = mut;
                weakSelf.displayPrograms = mut[date];
                
                if (weakSelf.displayPrograms.count == 0) {
                    [weakSelf.emptyView setState:EPGEmptyStateTypeNoData];
                    weakSelf.tableView.hidden = YES;
                } else {
                    [weakSelf.emptyView setState:EPGEmptyStateTypeNone];
                    weakSelf.tableView.hidden = NO;
                }
                [weakSelf.tableView reloadData];
                
                [weakSelf handleScrollAfterDataLoadForDate:date];
                [weakSelf startAutoScrollTimer];
            }
        }];
    }
}

- (NSDate *)startOfDayForDate:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    [calendar setTimeZone:[EPGManager sharedManager].epgTimeZone];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:date];
    return [calendar dateFromComponents:components];
}

@end