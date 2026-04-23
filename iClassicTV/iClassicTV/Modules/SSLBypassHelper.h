//
//  SSLBypassHelper.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

// 网络安全模块，用于绕过 iOS 6 过期的 HTTPS 证书校验
@interface SSLBypassHelper : NSObject

// 针对指定域名强制系统信任其 HTTPS 证书
+ (void)bypassSSLForHost:(NSString *)host;

@end