//
//  NSString+EncodingHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "NSString+EncodingHelper.h"
#import "SSLBypassHelper.h" // 新增：引入 SSLBypassHelper 以确保 https 链接也能绕过 iOS 6 证书校验
#import "UserAgentManager.h" // 新增：引入 UA 管理器以获取动态 UA

@implementation NSString (EncodingHelper)

+ (NSString *)stringWithContentsOfURLWithFallback:(NSURL *)url {
    if (!url) return nil;
    
    // 优化：采用 NSMutableURLRequest 替代直接的 stringWithContentsOfURL，增加 15 秒超时和重试控制，防止后台线程长时间阻塞假死
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:15.0];
    
    // 优化：使用 UserAgentManager 单例获取用户选择的或系统适配的默认动态 UA，彻底移除硬编码
    NSString *userAgent = [[UserAgentManager sharedManager] currentUA];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    
    // 针对 HTTPS 链接应用 SSL 绕过策略
    if ([url.scheme.lowercaseString isEqualToString:@"https"]) {
        [SSLBypassHelper bypassSSLForHost:url.host];
    }
    
    NSData *data = nil;
    int maxRetry = 2; // 优化：最多尝试 2 次 (1次正常请求 + 1次重试)
    
    for (int i = 0; i < maxRetry; i++) {
        data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        if (data && data.length > 0) {
            break; // 请求成功，跳出重试循环
        }
        if (i < maxRetry - 1) {
            [NSThread sleepForTimeInterval:1.0]; // 失败后短暂休眠 1 秒再试
        }
    }
    
    if (!data) return nil;
    
    // 优先尝试 UTF-8 编码读取
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) {
        // 失败则回退尝试 GBK/GB18030 编码读取
        NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        content = [[NSString alloc] initWithData:data encoding:gbkEncoding];
    }
    
    return content;
}

+ (NSString *)stringWithContentsOfFileWithFallback:(NSString *)path {
    if (!path) return nil;
    
    NSError *error = nil;
    // 优先尝试 UTF-8 编码读取
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!content) {
        // 失败则回退尝试 GBK/GB18030 编码读取
        NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        content = [NSString stringWithContentsOfFile:path encoding:gbkEncoding error:nil];
    }
    return content;
}

@end