//
//  SourceManagerViewController.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

// 直播源管理子页面 (我的直播源)
@interface SourceManagerViewController : UITableViewController <UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *sources;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, copy) NSString *tempM3UData;   // 新增：用于弹窗间传递下载的数据或文本
@property (nonatomic, copy) NSString *tempURLString; // 新增：用于弹窗间传递原始的 URL

@end