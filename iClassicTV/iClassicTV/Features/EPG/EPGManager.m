//
//  EPGManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGManager.h"
#import "EPGManager+Internal.h"
#import "EPGManager+Sources.h"
#import "EPGManager+Cache.h"
#import "EPGManager+Update.h"

@implementation EPGManager

+ (instancetype)sharedManager {
    static EPGManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryNormalizeSet = [NSCharacterSet characterSetWithCharactersInString:@"-_ "];
        [self loadSourcesFromDisk];
        [self loadCacheFromDisk];
        [self startAutoUpdateTimer];
        
        // [修复] 延迟1秒后主动执行一次启动更新检测，解决原先因未主动调用而被迫等待30秒定时器触发的延迟问题
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkAndAutoUpdateEPG];
        });
    }
    return self;
}

#pragma mark - Properties

- (BOOL)isEPGEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kEPGEnabledKey];
}

- (void)setIsEPGEnabled:(BOOL)isEPGEnabled {
    [[NSUserDefaults standardUserDefaults] setBool:isEPGEnabled forKey:kEPGEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)autoUpdateOnLaunch {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kEPGAutoUpdateKey];
}

- (void)setAutoUpdateOnLaunch:(BOOL)autoUpdateOnLaunch {
    [[NSUserDefaults standardUserDefaults] setBool:autoUpdateOnLaunch forKey:kEPGAutoUpdateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)autoUpdateOnExpire {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kEPGAutoUpdateExpireKey];
}

- (void)setAutoUpdateOnExpire:(BOOL)autoUpdateOnExpire {
    [[NSUserDefaults standardUserDefaults] setBool:autoUpdateOnExpire forKey:kEPGAutoUpdateExpireKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)scheduledUpdateTimeString {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kEPGScheduledUpdateTimeKey];
}

- (void)setScheduledUpdateTimeString:(NSString *)scheduledUpdateTimeString {
    if (!scheduledUpdateTimeString || scheduledUpdateTimeString.length == 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEPGScheduledUpdateTimeKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:scheduledUpdateTimeString forKey:kEPGScheduledUpdateTimeKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)lastEPGUpdateTime {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kEPGLastUpdateTimeKey];
}

- (NSTimeZone *)epgTimeZone {
    NSString *tzName = [[NSUserDefaults standardUserDefaults] stringForKey:kEPGTimeZoneNameKey];
    if (tzName && tzName.length > 0) {
        if ([tzName isEqualToString:@"System"]) {
            return [NSTimeZone localTimeZone];
        }
        NSTimeZone *tz = [NSTimeZone timeZoneWithName:tzName];
        if (tz) return tz;
    }
    return [NSTimeZone localTimeZone];
}

- (void)setEpgTimeZone:(NSTimeZone *)epgTimeZone {
    if (!epgTimeZone) {
        [[NSUserDefaults standardUserDefaults] setObject:@"System" forKey:kEPGTimeZoneNameKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:epgTimeZone.name forKey:kEPGTimeZoneNameKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSInteger)autoScrollTimeout {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kEPGAutoScrollTimeoutKey] == nil) {
        return 10;
    }
    return [[NSUserDefaults standardUserDefaults] integerForKey:kEPGAutoScrollTimeoutKey];
}

- (void)setAutoScrollTimeout:(NSInteger)autoScrollTimeout {
    [[NSUserDefaults standardUserDefaults] setInteger:autoScrollTimeout forKey:kEPGAutoScrollTimeoutKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *)epgSources {
    return [self.internalSources copy];
}

- (NSString *)epgSourceURL {
    for (NSDictionary *source in self.internalSources) {
        if ([source[@"isActive"] boolValue]) {
            return source[@"url"];
        }
    }
    return @"";
}

- (NSString *)epgSourceType {
    for (NSDictionary *source in self.internalSources) {
        if ([source[@"isActive"] boolValue]) {
            NSString *type = source[@"type"];
            return (type && type.length > 0) ? type : @"xml";
        }
    }
    return @"xml";
}

- (BOOL)isDynamicEPGSource {
    NSString *type = [self epgSourceType];
    return [type isEqualToString:@"diyp"] || [type isEqualToString:@"epginfo"];
}

@end