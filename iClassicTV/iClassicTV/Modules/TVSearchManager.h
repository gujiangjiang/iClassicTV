//
//  TVSearchManager.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Channel;

@protocol TVSearchManagerDelegate <NSObject>
// 当用户在搜索结果中点击某个频道时触发
- (void)searchManager:(id)manager didSelectChannel:(Channel *)channel;
// 当用户在搜索结果中点击某个频道的右侧详情按钮（切换线路）时触发
- (void)searchManager:(id)manager accessoryButtonTappedForChannel:(Channel *)channel;
@end

@interface TVSearchManager : NSObject <UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate>

// 暴露控件以便外部将其添加至 TableView Header
@property (nonatomic, strong, readonly) UISearchBar *searchBar;
@property (nonatomic, strong, readonly) UISearchDisplayController *searchController;

@property (nonatomic, weak) id<TVSearchManagerDelegate> delegate;

// 供外部注入的全量频道数据池
@property (nonatomic, strong) NSArray *sourceChannels;

// 初始化时需要指定在哪个控制器上展示搜索界面
- (instancetype)initWithContentsController:(UIViewController *)controller;

// 刷新搜索结果列表（如切换线路后更新当前线路状态）
- (void)reloadSearchResults;

// 提取当前搜索模块独立缓存的图片（防止外部列表找不到图）
- (UIImage *)cachedImageForChannel:(Channel *)channel;

@end