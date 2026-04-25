//
//  PlayerViewController.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-23.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PlayerViewController : UIViewController

// 接收外部传入的视频播放地址
@property (nonatomic, copy) NSString *videoURLString;
// 接收外部传入的频道名称，用于在播放器顶部显示
@property (nonatomic, copy) NSString *channelTitle;
// 接收外部传入的 tvg-name，用于 EPG 节目单的优先精准匹配
@property (nonatomic, copy) NSString *tvgName;
// 接收外部传入的频道 Logo 图片，用于在锁屏界面显示
@property (nonatomic, strong) UIImage *channelLogo;
// 新增：接收外部传入的回放源抓取模板 (catchup-source)
@property (nonatomic, copy) NSString *catchupSource;

@end