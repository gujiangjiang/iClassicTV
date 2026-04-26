//
//  PlayerEPGView.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView.h"
#import "PlayerEPGView+Internal.h"
#import "PlayerEPGView+Data.h"
#import "PlayerEPGView+Table.h"
#import "PlayerEPGView+Scroll.h"
#import "EPGManager.h"
#import "EPGProgram.h"

@implementation PlayerEPGView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        
        self.timeFormatter = [[NSDateFormatter alloc] init];
        [self.timeFormatter setTimeZone:[EPGManager sharedManager].epgTimeZone];
        [self.timeFormatter setDateFormat:@"HH:mm"];
        
        self.dateBar = [[PlayerEPGDateBar alloc] initWithFrame:CGRectZero];
        self.dateBar.delegate = self;
        [self addSubview:self.dateBar];
        
        self.separatorLine = [[UIView alloc] initWithFrame:CGRectZero];
        self.separatorLine.backgroundColor = self.isIOS7 ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor darkGrayColor];
        [self addSubview:self.separatorLine];
        
        self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.separatorColor = self.isIOS7 ? [UIColor colorWithWhite:0.8 alpha:1.0] : [UIColor darkGrayColor];
        if (self.isIOS7) {
            self.tableView.separatorInset = UIEdgeInsetsZero;
        }
        [self addSubview:self.tableView];
        
        self.emptyView = [[PlayerEPGEmptyView alloc] initWithFrame:CGRectZero];
        self.emptyView.delegate = self;
        [self addSubview:self.emptyView];
    }
    return self;
}

- (void)dealloc {
    [self stopAutoScrollTimer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat viewWidth = self.bounds.size.width;
    CGFloat viewHeight = self.bounds.size.height;
    
    self.dateBar.frame = CGRectMake(0, 0, viewWidth, 40);
    self.separatorLine.frame = CGRectMake(0, 39, viewWidth, 1);
    self.tableView.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
    self.emptyView.frame = CGRectMake(0, 40, viewWidth, viewHeight - 40);
}

- (void)setReplayingProgram:(EPGProgram *)replayingProgram {
    _replayingProgram = replayingProgram;
    [self.tableView reloadData];
    [self scrollToCurrentProgram];
    [self startAutoScrollTimer];
}

#pragma mark - Public Methods (Forwarding)

// 避免 Incomplete implementation 警告，在主类中实现公开方法，并将逻辑转发给对应分类
- (void)reloadData {
    [self data_reloadData];
}

- (void)scrollToCurrentProgram {
    [self scroll_scrollToCurrentProgram];
}

#pragma mark - Program Queries

- (EPGProgram *)currentPlayingProgram {
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    NSDate *yesterdayStart = [todayStart dateByAddingTimeInterval:-86400];
    
    NSArray *programs = self.groupedPrograms[todayStart];
    for (EPGProgram *p in programs) {
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            return p;
        }
    }
    
    programs = self.groupedPrograms[yesterdayStart];
    for (EPGProgram *p in programs) {
        if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
            return p;
        }
    }
    return nil;
}

- (EPGProgram *)nextPlayingProgram {
    NSDate *now = [NSDate date];
    NSDate *todayStart = [self startOfDayForDate:now];
    NSDate *yesterdayStart = [todayStart dateByAddingTimeInterval:-86400];
    
    NSArray *programs = self.groupedPrograms[todayStart];
    if (programs) {
        for (NSInteger i = 0; i < programs.count; i++) {
            EPGProgram *p = programs[i];
            if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
                if (i + 1 < programs.count) return programs[i + 1];
                break;
            }
        }
    }
    
    programs = self.groupedPrograms[yesterdayStart];
    if (programs) {
        for (NSInteger i = 0; i < programs.count; i++) {
            EPGProgram *p = programs[i];
            if ([now compare:p.startTime] != NSOrderedAscending && [now compare:p.endTime] == NSOrderedAscending) {
                if (i + 1 < programs.count) return programs[i + 1];
                else return [self.groupedPrograms[todayStart] firstObject];
            }
        }
    }
    
    for (EPGProgram *p in self.groupedPrograms[todayStart]) {
        if ([p.startTime compare:now] == NSOrderedDescending) return p;
    }
    return nil;
}

- (void)updateTimeTick {
    if (self.displayPrograms.count == 0) return;
    
    NSDate *todayStart = [self startOfDayForDate:[NSDate date]];
    if (![self.selectedDate isEqualToDate:todayStart]) return;
    
    EPGProgram *current = [self currentPlayingProgram];
    
    BOOL programChanged = NO;
    if (!self.lastPlayingProgram && current) {
        programChanged = YES;
    } else if (self.lastPlayingProgram && !current) {
        programChanged = YES;
    } else if (self.lastPlayingProgram && current) {
        if (![self.lastPlayingProgram.startTime isEqualToDate:current.startTime]) {
            programChanged = YES;
        }
    }
    
    if (programChanged) {
        self.lastPlayingProgram = current;
        [self.tableView reloadData];
        if (!self.tableView.isDragging && !self.tableView.isDecelerating) {
            [self scrollToCurrentProgram];
        }
    }
}

@end