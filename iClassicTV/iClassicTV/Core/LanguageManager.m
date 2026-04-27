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
// 新增缓存的可用语言代码列表，避免频繁读取磁盘文件
@property (nonatomic, strong) NSArray *cachedAvailableLanguageCodes;
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
        
        [self loadAvailableLanguageCodes]; // 动态加载可用的语言包列表
        [self resolveCurrentLanguageCode];
        [self loadLanguageDict];
    }
    return self;
}

// 动态扫描 mainBundle 中的所有 json 文件，识别有效的语言包
- (void)loadAvailableLanguageCodes {
    NSArray *jsonPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"json" inDirectory:nil];
    NSMutableArray *codes = [NSMutableArray array];
    
    for (NSString *path in jsonPaths) {
        NSString *code = [[path lastPathComponent] stringByDeletingPathExtension];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            NSError *error = nil;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            // 只有成功解析且包含 "language_display_name" 字段的 JSON 文件才视为合法的语言包
            if (!error && [dict isKindOfClass:[NSDictionary class]] && dict[@"language_display_name"]) {
                [codes addObject:code];
            }
        }
    }
    self.cachedAvailableLanguageCodes = codes;
}

- (void)resolveCurrentLanguageCode {
    if ([self.savedLanguageCode isEqualToString:@"system"]) {
        // 跟随系统逻辑：获取系统当前的语言列表
        NSArray *preferredLanguages = [NSLocale preferredLanguages];
        NSString *matchedCode = nil;
        
        for (NSString *sysLang in preferredLanguages) {
            // 1. 尝试完全匹配 (例如系统是 zh-CN，并且有 zh-CN.json)
            if ([self.cachedAvailableLanguageCodes containsObject:sysLang]) {
                matchedCode = sysLang;
                break;
            }
            
            // 2. 尝试前缀匹配 (例如系统是 zh-Hans-CN，尝试匹配可用的 zh-CN 或者 zh)
            NSString *baseCode = [[sysLang componentsSeparatedByString:@"-"] firstObject];
            for (NSString *availCode in self.cachedAvailableLanguageCodes) {
                if ([availCode hasPrefix:baseCode]) {
                    matchedCode = availCode;
                    break;
                }
            }
            
            if (matchedCode) {
                break;
            }
        }
        
        // 存在匹配的语言包就使用匹配到的，不存在则回退到 en-US
        self.currentLanguageCode = matchedCode ? matchedCode : @"en-US";
        
    } else {
        // 用户指定了具体语言
        self.currentLanguageCode = self.savedLanguageCode;
    }
}

// 递归扁平化多级 JSON 字典
// 将形如 {"common": {"cancel": "取消"}} 转换为 {"common.cancel": "取消", "cancel": "取消"}
- (void)flattenDictionary:(NSDictionary *)dict into:(NSMutableDictionary *)result prefix:(NSString *)prefix {
    for (NSString *key in dict) {
        id value = dict[key];
        NSString *fullKey = prefix.length > 0 ? [NSString stringWithFormat:@"%@.%@", prefix, key] : key;
        
        if ([value isKindOfClass:[NSDictionary class]]) {
            // 递归处理嵌套字典
            [self flattenDictionary:value into:result prefix:fullKey];
        } else if ([value isKindOfClass:[NSString class]]) {
            // 存储完整的 dot-notation 键（例如 "common.cancel"）
            result[fullKey] = value;
            // 同时存储叶子键名，兼容旧的硬编码调用（例如 "cancel"）
            if (!result[key]) {
                result[key] = value;
            }
        }
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
                // 将多层嵌套字典扁平化展开，方便检索并兼容旧版本短命名
                NSMutableDictionary *flatDict = [NSMutableDictionary dictionary];
                [self flattenDictionary:dict into:flatDict prefix:@""];
                self.languageDict = flatDict;
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
    NSMutableArray *list = [NSMutableArray array];
    
    // 动态使用缓存的语言包代码生成支持的语言列表
    for (NSString *code in self.cachedAvailableLanguageCodes) {
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