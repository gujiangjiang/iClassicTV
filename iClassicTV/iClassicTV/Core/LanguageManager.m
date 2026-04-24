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
@property (nonatomic, copy) NSString *savedLanguageCode;
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
        // 读取用户缓存的语言偏好，如果没有设置过，默认为 "system"
        NSString *savedLanguage = [[NSUserDefaults standardUserDefaults] objectForKey:kCurrentLanguageKey];
        self.savedLanguageCode = savedLanguage.length > 0 ? savedLanguage : @"system";
        
        [self resolveCurrentLanguageCode];
        [self loadLanguageDict];
    }
    return self;
}

- (void)resolveCurrentLanguageCode {
    if ([self.savedLanguageCode isEqualToString:@"system"]) {
        // 跟随系统逻辑：获取系统当前的语言列表
        NSArray *languages = [NSLocale preferredLanguages];
        NSString *systemLanguage = languages.firstObject;
        
        // 简单判断：如果系统语言包含 "zh"，使用 zh-CN，否则一律用 en-US
        if ([systemLanguage hasPrefix:@"zh"]) {
            self.currentLanguageCode = @"zh-CN";
        } else {
            self.currentLanguageCode = @"en-US";
        }
    } else {
        // 用户指定了具体语言
        self.currentLanguageCode = self.savedLanguageCode;
    }
}

- (void)loadLanguageDict {
    // 尝试加载对应的 JSON 语言包文件
    NSString *path = [[NSBundle mainBundle] pathForResource:self.currentLanguageCode ofType:@"json"];
    
    // 如果找不到指定的语言包，回退到 en-US
    if (!path) {
        path = [[NSBundle mainBundle] pathForResource:@"en-US" ofType:@"json"];
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

- (NSArray *)availableLanguages {
    // 声明支持的语言包文件名
    NSArray *supportedCodes = @[@"zh-CN", @"en-US"];
    NSMutableArray *list = [NSMutableArray array];
    
    for (NSString *code in supportedCodes) {
        NSString *path = [[NSBundle mainBundle] pathForResource:code ofType:@"json"];
        if (path) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (data) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
                // 读取 JSON 头部定义的展示名称，如果没有则回退使用 code
                NSString *displayName = dict[@"language_display_name"] ?: code;
                [list addObject:@{@"code": code, @"name": displayName}];
            }
        }
    }
    return list;
}

- (NSString *)currentLanguageDisplayName {
    // 直接从已加载的内存字典中提取名称
    return self.languageDict[@"language_display_name"] ?: self.currentLanguageCode;
}

- (void)changeLanguageTo:(NSString *)languageCode {
    if (!languageCode || [self.savedLanguageCode isEqualToString:languageCode]) {
        return;
    }
    
    self.savedLanguageCode = languageCode;
    [[NSUserDefaults standardUserDefaults] setObject:languageCode forKey:kCurrentLanguageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 重新解析真实的语言代码并加载对应的字典
    [self resolveCurrentLanguageCode];
    [self loadLanguageDict];
    
    // 发送全局通知，让各个界面（特别是设置界面）即刻刷新文本
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageDidChangeNotification" object:nil];
}

@end