//
//  ChannelListViewController.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "ChannelListViewController.h"
#import "Channel.h"
#import <MediaPlayer/MediaPlayer.h>
#import "PlayerViewController.h" // 新增：引入独立的播放器组件

// ================= 新增：iOS 6 专属 HTTPS 证书绕过 Hack =================
// 由于 iOS 6 系统的根证书早已过期，且不支持许多现代 TLS 协议，
// 直接访问现代证书的 HTTPS 链接会报 -9813 (kCFStreamErrorDomainSSL) 错误。
// 这里暴露 NSURLRequest 的私有方法，用于强制系统信任指定的 HTTPS 域名。
// （注：作为复古设备专用 App，无需顾虑 App Store 的私有 API 审核限制）
@interface NSURLRequest (PrivateSSLBypass)
+ (void)setAllowsAnyHTTPSCertificate:(BOOL)allow forHost:(NSString *)host;
@end
// ===================================================================

@interface ChannelListViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) Channel *selectedChannel;
@property (nonatomic, strong) NSCache *imageCache; // 新增：用于缓存频道LOGO，避免滑动时重复下载和绘制
@end

@implementation ChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 55.0;
    self.imageCache = [[NSCache alloc] init]; // 初始化图片缓存
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"ChannelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
    }
    
    Channel *ch = self.channels[indexPath.row];
    cell.textLabel.text = ch.name;
    
    // 如果有多源，显示蓝色信息按钮，否则不显示
    if (ch.urls.count > 1) {
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"📺 多线路支持 (%lu 条)", (unsigned long)ch.urls.count];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.detailTextLabel.text = @"标准线路";
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    // ================= 新增：处理 LOGO 显示核心逻辑 =================
    // 使用 URL 或频道名作为缓存 Key
    NSString *logoKey = ch.logo.length > 0 ? ch.logo : ch.name;
    UIImage *cachedImage = [self.imageCache objectForKey:logoKey];
    
    if (cachedImage) {
        // 命中缓存，直接显示
        cell.imageView.image = cachedImage;
    } else {
        // 先设置一个动态生成的默认首字母 LOGO，防止图片下载慢导致错位空白
        UIImage *defaultLogo = [self generateDefaultLogoWithName:ch.name];
        cell.imageView.image = defaultLogo;
        
        if (ch.logo.length > 0) {
            // 开启后台异步下载真实 LOGO
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // 1. 清理 URL 字符串，去除前后空格和换行
                NSString *cleanURLStr = [ch.logo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSURL *url = [NSURL URLWithString:cleanURLStr];
                if (!url) {
                    // 如果 URL 包含中文或其他特殊字符，进行 Encode
                    url = [NSURL URLWithString:[cleanURLStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                }
                
                // ===== [DEBUG 探针 1：检查 URL 解析] =====
                if (!url) {
                    NSLog(@"[LOGO DEBUG] ❌ URL解析失败，原始字符串: %@", cleanURLStr);
                } else {
                    NSLog(@"[LOGO DEBUG] 🌐 准备请求 LOGO: %@", url.absoluteString);
                }
                
                if (url) {
                    // ===== [核心修复：绕过 iOS 6 HTTPS 证书校验] =====
                    // 针对当前图片的域名，强制系统信任其 HTTPS 证书
                    if ([url.scheme.lowercaseString isEqualToString:@"https"]) {
                        if ([NSURLRequest respondsToSelector:@selector(setAllowsAnyHTTPSCertificate:forHost:)]) {
                            [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:url.host];
                        }
                    }
                    
                    // 2. 使用 NSURLConnection 伪装 User-Agent
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25" forHTTPHeaderField:@"User-Agent"];
                    [request setTimeoutInterval:15.0];
                    
                    NSURLResponse *response = nil;
                    NSError *error = nil;
                    
                    // 同步请求在全局队列（非主线程）中运行是安全的
                    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                    
                    // ===== [DEBUG 探针 2：检查网络响应与错误] =====
                    if (error) {
                        NSLog(@"[LOGO DEBUG] ❌ 下载失败! 频道: %@, 错误原因: %@", ch.name, error.localizedDescription);
                    } else if (response) {
                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                        NSLog(@"[LOGO DEBUG] ✅ 收到响应! 频道: %@, HTTP 状态码: %ld, 数据大小: %lu bytes", ch.name, (long)httpResponse.statusCode, (unsigned long)data.length);
                    }
                    
                    if (data && !error) {
                        UIImage *downloadedImage = [UIImage imageWithData:data];
                        
                        // ===== [DEBUG 探针 3：检查图片数据是否合法] =====
                        if (!downloadedImage) {
                            NSLog(@"[LOGO DEBUG] ❌ 图片转换失败! 频道: %@。下载的数据可能不是有效的图片格式，或者内容是防盗链 HTML 页面", ch.name);
                        }
                        
                        if (downloadedImage) {
                            // 【优化】等比例缩放并居中到固定尺寸，避免奇形怪状的图标撑破排版
                            UIImage *resizedImage = [self resizeAndPadImage:downloadedImage toSize:CGSizeMake(40, 40)];
                            // 存入缓存
                            [self.imageCache setObject:resizedImage forKey:logoKey];
                            
                            // 回到主线程更新 UI
                            dispatch_async(dispatch_get_main_queue(), ^{
                                // 获取当前可见的 cell，如果滚出了屏幕则拿不到，避免复用导致张冠李戴
                                UITableViewCell *updateCell = [tableView cellForRowAtIndexPath:indexPath];
                                if (updateCell) {
                                    updateCell.imageView.image = resizedImage;
                                    [updateCell setNeedsLayout]; // 强制刷新 iOS 6 单元格布局
                                }
                            });
                        }
                    }
                }
            });
        } else {
            // 如果 M3U 原本就没有提供 LOGO，把默认 LOGO 缓存起来，避免每次滑动重复用 CPU 绘制
            [self.imageCache setObject:defaultLogo forKey:logoKey];
        }
    }
    // ==============================================================
    
    return cell;
}

#pragma mark - 新增：图片处理辅助方法

// 优化：等比例缩放图片并居中，生成固定尺寸的图片 (Aspect Fit)
- (UIImage *)resizeAndPadImage:(UIImage *)image toSize:(CGSize)targetSize {
    CGFloat scaleRatio = MIN(targetSize.width / image.size.width, targetSize.height / image.size.height);
    CGSize scaledSize = CGSizeMake(image.size.width * scaleRatio, image.size.height * scaleRatio);
    
    // 使用主屏幕缩放比例，保证 Retina 屏幕清晰度
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, [UIScreen mainScreen].scale);
    
    // 计算居中位置
    CGFloat x = (targetSize.width - scaledSize.width) / 2.0;
    CGFloat y = (targetSize.height - scaledSize.height) / 2.0;
    [image drawInRect:CGRectMake(x, y, scaledSize.width, scaledSize.height)];
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}

// 优化：动态生成默认LOGO (纯色背景 + 频道首字符，简单且不依赖外部资源)
- (UIImage *)generateDefaultLogoWithName:(NSString *)name {
    CGSize size = CGSizeMake(40, 40);
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 根据名称的 Hash 值动态生成一个柔和的专属背景色，让每个频道的颜色都不太一样
    NSUInteger hash = name.hash;
    CGFloat r = ((hash & 0xFF0000) >> 16) / 255.0;
    CGFloat g = ((hash & 0x00FF00) >> 8) / 255.0;
    CGFloat b = (hash & 0x0000FF) / 255.0;
    // 提亮颜色变为粉彩/马卡龙色系，避免文字看不清
    UIColor *bgColor = [UIColor colorWithRed:(r + 1.0)/2.0 green:(g + 1.0)/2.0 blue:(b + 1.0)/2.0 alpha:1.0];
    
    [bgColor setFill];
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    
    // 提取首字符（若没名字保底用 TV）
    NSString *firstChar = name.length > 0 ? [name substringToIndex:1] : @"T";
    UIFont *font = [UIFont boldSystemFontOfSize:18];
    UIColor *textColor = [UIColor darkGrayColor];
    
    // 兼容 iOS 6 的原生文字绘制方式
    CGSize textSize = [firstChar sizeWithFont:font];
    CGRect textRect = CGRectMake((size.width - textSize.width) / 2.0,
                                 (size.height - textSize.height) / 2.0,
                                 textSize.width,
                                 textSize.height);
    [textColor set];
    [firstChar drawInRect:textRect withFont:font];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

#pragma mark - 现有交互逻辑

// 核心逻辑 A：直接点击列表项 -> 记忆播放
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Channel *ch = self.channels[indexPath.row];
    
    NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[ch persistenceKey]];
    
    if (savedIndex >= ch.urls.count) {
        // 线路丢失回退机制
        [self showToast:[NSString stringWithFormat:@"线路 %ld 已失效，回到默认线路", (long)savedIndex + 1]];
        savedIndex = 0;
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[ch persistenceKey]];
    }
    
    [self playVideoWithURL:ch.urls[savedIndex] title:ch.name];
}

// 核心逻辑 B：点击右侧蓝色小箭头 -> 线路切换
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    self.selectedChannel = self.channels[indexPath.row];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"切换播放线路"
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    
    NSInteger currentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[self.selectedChannel persistenceKey]];
    
    for (int i = 0; i < self.selectedChannel.urls.count; i++) {
        NSString *title = (i == currentIndex) ? [NSString stringWithFormat:@"线路 %d (当前选择)", i+1] : [NSString stringWithFormat:@"线路 %d", i+1];
        [sheet addButtonWithTitle:title];
    }
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    NSInteger sourceIndex = buttonIndex - 1; // 减去第一个默认 index
    [[NSUserDefaults standardUserDefaults] setInteger:sourceIndex forKey:[self.selectedChannel persistenceKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.tableView reloadData]; // 刷新界面文字
    [self playVideoWithURL:self.selectedChannel.urls[sourceIndex] title:self.selectedChannel.name];
}

// 模拟 iOS 风格 Toast (使用带定时自动消失的 UIAlertView)
- (void)showToast:(NSString *)message {
    UIAlertView *toast = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [toast show];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissWithClickedButtonIndex:0 animated:YES];
    });
}

- (void)playVideoWithURL:(NSString *)urlString title:(NSString *)title {
    // 读取用户的播放器偏好设置
    NSInteger playerPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerTypePref"];
    
    if (playerPref == 1) {
        // 1. 使用 iOS 原生全屏播放器 (MPMoviePlayerViewController)
        NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        MPMoviePlayerViewController *playerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
        
        // 读取全屏逻辑偏好，尝试干预原生播放器的初始方向 (原生播放器对方向的控制较弱，这里尽量尝试)
        NSInteger orientationPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"PlayerOrientationPref"];
        if (orientationPref == 1) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
        } else if (orientationPref == 2) {
            [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIInterfaceOrientationPortrait] forKey:@"orientation"];
        }
        
        [self presentMoviePlayerViewControllerAnimated:playerVC];
        [playerVC.moviePlayer play];
        
    } else {
        // 0. (默认) 启动我们自己开发的独立播放器外观组件
        PlayerViewController *playerVC = [[PlayerViewController alloc] init];
        playerVC.videoURLString = urlString;
        playerVC.channelTitle = title;
        // 优化：恢复为 iOS 默认的底部弹出动画，与原生播放器体验保持一致
        playerVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:playerVC animated:YES completion:nil];
    }
}

@end