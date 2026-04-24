//
//  NetworkManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-24.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkManager : NSObject

+ (instancetype)sharedManager;

/**
 * 同步下载纯数据 (适用于下载图片、Logo、Zip文件等)
 * 内部已包含 15秒超时、失败自动重试1次、User-Agent 自动注入、HTTPS 证书校验自动绕过
 *
 * @param url 目标链接
 * @return 下载好的 NSData，如果失败则返回 nil
 */
- (NSData *)downloadDataSyncFromURL:(NSURL *)url;

/**
 * 同步下载文本字符串 (适用于 M3U 直播源、EPG 数据等)
 * 在下载纯数据的基础上，自动进行 UTF-8 和 GBK 编码的双重智能解析回退
 *
 * @param url 目标链接
 * @return 解析好的字符串，如果失败则返回 nil
 */
- (NSString *)downloadStringSyncFromURL:(NSURL *)url;

@end