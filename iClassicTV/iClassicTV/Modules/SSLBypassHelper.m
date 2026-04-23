//
//  SSLBypassHelper.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "SSLBypassHelper.h"

@interface NSURLRequest (PrivateSSLBypass)
+ (void)setAllowsAnyHTTPSCertificate:(BOOL)allow forHost:(NSString *)host;
@end

@implementation SSLBypassHelper

+ (void)bypassSSLForHost:(NSString *)host {
    if (!host) return;
    if ([NSURLRequest respondsToSelector:@selector(setAllowsAnyHTTPSCertificate:forHost:)]) {
        [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:host];
    }
}

@end