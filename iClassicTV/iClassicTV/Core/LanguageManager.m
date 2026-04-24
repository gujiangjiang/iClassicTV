//
//  LanguageManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "LanguageManager.h"

static NSString * const kCurrentLanguageKey = @"iClassicTV_CurrentLanguage";

@interface LanguageManager ()
@property (nonatomic, strong) NSDictionary *languageDict;
@property (nonatomic, copy) NSString *currentLanguageCode;
@end

@implementation LanguageManager

+ (instancetype)sharedManager {
    static LanguageManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 读取系统默认语言或用户缓存的语言
        NSString *savedLanguage = [[NSUserDefaults standardUserDefaults] objectForKey:kCurrentLanguageKey];
        if (savedLanguage) {
            _currentLanguageCode = savedLanguage;
        } else {
            // 如果没有设置过，获取系统当前的语言列表
            NSArray *languages = [NSLocale preferredLanguages];
            NSString *systemLanguage = languages.firstObject;
            
            // 简单判断：如果系统语言包含 "zh"，默认使用 zh-CN，否则一律用英文
            if ([systemLanguage hasPrefix:@"zh"]) {
                _currentLanguageCode = @"zh-CN";
            } else {
                _currentLanguageCode = @"en";
            }
        }
        [self loadLanguageDict];
    }
    return self;
}

- (void)loadLanguageDict {
    // 尝试加载对应的 JSON 语言包文件
    NSString *path = [[NSBundle mainBundle] pathForResource:self.currentLanguageCode ofType:@"json"];
    
    // 如果找不到指定的语言包，回退到英文
    if (!path) {
        path = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"json"];
    }
    
    if (path) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            NSError *error = nil;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            if (!error && [dict isKindOfClass:[NSDictionary class]]) {
                self.languageDict = dict;
                return;
            }
        }
    }
    
    // 极端情况下给个空字典防止崩溃
    self.languageDict = @{};
}

- (NSString *)localizedStringForKey:(NSString *)key {
    if (!key) return @"";
    NSString *value = self.languageDict[key];
    // 如果 JSON 里没有这个 key，直接原样返回 key 作为后备提示
    return value ? value : key;
}

- (void)changeLanguageTo:(NSString *)languageCode {
    if (!languageCode || [self.currentLanguageCode isEqualToString:languageCode]) {
        return;
    }
    self.currentLanguageCode = languageCode;
    [[NSUserDefaults standardUserDefaults] setObject:languageCode forKey:kCurrentLanguageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 重新加载对应的语言字典
    [self loadLanguageDict];
    
    // 可以在这里发送一个全局通知，通知各个界面刷新文本
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageDidChangeNotification" object:nil];
}

@end