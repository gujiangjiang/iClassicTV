//
//  LanguageManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

// 提供一个便捷的宏，方便在全局调用替换原本的硬编码中文字符串
#define LocalizedString(key) [[LanguageManager sharedManager] localizedStringForKey:(key)]

@interface LanguageManager : NSObject

+ (instancetype)sharedManager;

// 当前实际在使用的语言代码（例如 @"zh-CN" 或 @"en-US"）
@property (nonatomic, copy, readonly) NSString *currentLanguageCode;

// 用户保存的设置选项（@"system" 代表跟随系统，否则就是具体的语言代码）
@property (nonatomic, copy, readonly) NSString *savedLanguageCode;

/**
 * 根据指定的 key 从 JSON 文件中获取对应的多语言字符串
 */
- (NSString *)localizedStringForKey:(NSString *)key;

/**
 * 获取所有受支持的语言列表
 * 返回数组，元素为字典，包含 code 和 name (动态从 json 读取)
 */
- (NSArray *)availableLanguages;

/**
 * 获取当前正在使用的语言的展示名称（比如："简体中文"）
 */
- (NSString *)currentLanguageDisplayName;

/**
 * 手动切换语言
 * @param languageCode 例如 @"zh-CN"、@"en-US"，或者传入 @"system" 代表跟随系统
 */
- (void)changeLanguageTo:(NSString *)languageCode;

@end