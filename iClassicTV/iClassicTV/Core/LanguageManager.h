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

// 获取当前激活的语言代码（例如 @"zh-CN" 或 @"en"）
@property (nonatomic, copy, readonly) NSString *currentLanguageCode;

/**
 * 根据指定的 key 从 JSON 文件中获取对应的多语言字符串
 */
- (NSString *)localizedStringForKey:(NSString *)key;

/**
 * 手动切换语言
 * @param languageCode 例如 @"zh-CN" 或 @"en"
 */
- (void)changeLanguageTo:(NSString *)languageCode;

@end