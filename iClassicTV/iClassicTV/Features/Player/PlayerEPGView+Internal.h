//
//  PlayerEPGView+Internal.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-26.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "PlayerEPGView.h"
#import "PlayerEPGDateBar.h"
#import "PlayerEPGEmptyView.h"
#import "EPGProgram.h"

// 内部属性声明（仅保留属性，不声明方法，避免主类出现未实现警告）
@interface PlayerEPGView ()

@property (nonatomic, strong) PlayerEPGDateBar *dateBar;
@property (nonatomic, strong) PlayerEPGEmptyView *emptyView;
@property (nonatomic, strong) UIView *separatorLine;
@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSArray *availableDates;
@property (nonatomic, strong) NSDictionary *groupedPrograms;
@property (nonatomic, strong) NSArray *displayPrograms;
@property (nonatomic, strong) NSDate *selectedDate;
@property (nonatomic, copy) NSString *currentChannelName;

@property (nonatomic, strong) EPGProgram *lastPlayingProgram;
@property (nonatomic, strong) NSTimer *autoScrollTimer;
@property (nonatomic, assign) BOOL isIOS7;

@end