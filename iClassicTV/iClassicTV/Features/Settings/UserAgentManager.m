//
//  UserAgentManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "UserAgentManager.h"
#import <UIKit/UIKit.h>

// NSUserDefaults 存储使用的 Key
static NSString * const kUAManagerListKey = @"kUAManagerListKey";
static NSString * const kUAManagerSelectedIndexKey = @"kUAManagerSelectedIndexKey";

@interface UserAgentManager ()

@property (nonatomic, strong) NSMutableArray *uaList;
@property (nonatomic, assign) NSInteger selectedIndex;

@end

@implementation UserAgentManager

+ (instancetype)sharedManager {
    static UserAgentManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UserAgentManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadData];
    }
    return self;
}

// 核心逻辑：根据当前设备的 iOS 版本动态生成一个最契合视频播放的默认 UA
- (NSString *)generateDefaultUA {
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSString *model = [[UIDevice currentDevice] model];
    // 将 6.1.3 转换为 6_1_3，以符合标准的系统 UA 格式
    NSString *osVersionUnderscore = [osVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    // 采用 AppleCoreMedia 格式，绝大部分 IPTV 直播源对该格式的兼容性最好
    return [NSString stringWithFormat:@"AppleCoreMedia/1.0.0.%@ (%@; U; CPU OS %@ like Mac OS X; zh_cn)", osVersion, model, osVersionUnderscore];
}

- (void)loadData {
    NSArray *savedList = [[NSUserDefaults standardUserDefaults] objectForKey:kUAManagerListKey];
    
    if (savedList && savedList.count > 0) {
        self.uaList = [NSMutableArray arrayWithArray:savedList];
        
        // 动态校验：无论本地存储了什么，强制刷新第 0 项（默认UA）的值，防止用户系统升级后依然使用老版本的 UA
        NSMutableDictionary *defaultDict = [self.uaList.firstObject mutableCopy];
        if ([defaultDict[@"isDefault"] boolValue]) {
            defaultDict[@"ua"] = [self generateDefaultUA];
            [self.uaList replaceObjectAtIndex:0 withObject:defaultDict];
        }
    } else {
        // 如果是首次启动应用，初始化默认的 UA 数据
        NSDictionary *defaultUA = @{
                                    @"name": @"【默认】系统动态适配",
                                    @"ua": [self generateDefaultUA],
                                    @"isDefault": @YES
                                    };
        self.uaList = [NSMutableArray arrayWithObject:defaultUA];
        [[NSUserDefaults standardUserDefaults] setObject:self.uaList forKey:kUAManagerListKey];
    }
    
    self.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kUAManagerSelectedIndexKey];
    // 防呆处理：如果越界，强制归零
    if (self.selectedIndex >= self.uaList.count || self.selectedIndex < 0) {
        self.selectedIndex = 0;
    }
}

- (void)saveData {
    [[NSUserDefaults standardUserDefaults] setObject:self.uaList forKey:kUAManagerListKey];
    [[NSUserDefaults standardUserDefaults] setInteger:self.selectedIndex forKey:kUAManagerSelectedIndexKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)currentUA {
    if (self.selectedIndex >= 0 && self.selectedIndex < self.uaList.count) {
        NSDictionary *dict = self.uaList[self.selectedIndex];
        return dict[@"ua"];
    }
    return [self generateDefaultUA];
}

- (NSArray *)allUAs {
    return [self.uaList copy];
}

- (NSInteger)currentSelectedIndex {
    return self.selectedIndex;
}

- (void)selectUAAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.uaList.count) {
        self.selectedIndex = index;
        [self saveData];
    }
}

- (void)addUAWithName:(NSString *)name uaString:(NSString *)uaString {
    if (name.length == 0 || uaString.length == 0) return;
    NSDictionary *newUA = @{
                            @"name": name,
                            @"ua": uaString,
                            @"isDefault": @NO
                            };
    [self.uaList addObject:newUA];
    [self saveData];
}

- (BOOL)deleteUAAtIndex:(NSInteger)index {
    // 索引 0 是系统的默认 UA，绝对不允许删除
    if (index <= 0 || index >= self.uaList.count) {
        return NO;
    }
    
    [self.uaList removeObjectAtIndex:index];
    
    // 逻辑修正：如果被删除的 UA 正好是当前正在使用的，则自动退回到使用默认 UA
    if (self.selectedIndex == index) {
        self.selectedIndex = 0;
    } else if (self.selectedIndex > index) {
        // 如果删除的是当前选中项之前的项，索引需减一以保持选中目标不变
        self.selectedIndex -= 1;
    }
    
    [self saveData];
    return YES;
}

@end