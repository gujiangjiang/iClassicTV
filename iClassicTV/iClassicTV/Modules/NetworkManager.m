//
//  NetworkManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "NetworkManager.h"
#import "UserAgentManager.h"
#import "SSLBypassHelper.h"

@implementation NetworkManager

+ (instancetype)sharedManager {
    static NetworkManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

// 私有方法：统一构建 Request，集中管理所有网络配置参数
- (NSMutableURLRequest *)buildRequestWithURL:(NSURL *)url {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:15.0]; // 统一 15 秒超时
    
    // 统一从 UA 管理器获取当前的动态 User-Agent
    NSString *userAgent = [[UserAgentManager sharedManager] currentUA];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    
    // 统一拦截并绕过 HTTPS 证书校验 (适配 iOS 6)
    if ([url.scheme.lowercaseString isEqualToString:@"https"]) {
        [SSLBypassHelper bypassSSLForHost:url.host];
    }
    
    return request;
}

- (NSData *)downloadDataSyncFromURL:(NSURL *)url {
    if (!url) return nil;
    
    NSMutableURLRequest *request = [self buildRequestWithURL:url];
    NSData *data = nil;
    int maxRetry = 2; // 最多尝试 2 次 (1次正常请求 + 1次失败重试)
    
    for (int i = 0; i < maxRetry; i++) {
        data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        if (data && data.length > 0) {
            break; // 请求成功，跳出重试循环
        }
        if (i < maxRetry - 1) {
            [NSThread sleepForTimeInterval:1.0]; // 失败后短暂休眠 1 秒再试
        }
    }
    
    return data;
}

- (NSString *)downloadStringSyncFromURL:(NSURL *)url {
    NSData *data = [self downloadDataSyncFromURL:url];
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

@end