//
//  TVSearchManager.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-27.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "TVSearchManager.h"
#import "Channel.h"
#import "NetworkManager.h"
#import "UIImage+LogoHelper.h"
#import "NSString+EncodingHelper.h"
#import "LanguageManager.h"

@interface TVSearchManager ()
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISearchDisplayController *searchController;
@property (nonatomic, strong) NSArray *filteredChannels;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, weak) UIViewController *contentsController;
@end

@implementation TVSearchManager

- (instancetype)initWithContentsController:(UIViewController *)controller {
    self = [super init];
    if (self) {
        _contentsController = controller;
        _imageCache = [[NSCache alloc] init];
        
        _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, controller.view.bounds.size.width, 44)];
        _searchBar.delegate = self;
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // 兼容 iOS 6 的原生搜索呈现方案
        _searchController = [[UISearchDisplayController alloc] initWithSearchBar:_searchBar contentsController:controller];
        _searchController.delegate = self;
        _searchController.searchResultsDataSource = self;
        _searchController.searchResultsDelegate = self;
#pragma clang diagnostic pop
        
        // 监听多语言切换通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLanguageChange) name:@"LanguageDidChangeNotification" object:nil];
        
        [self handleLanguageChange];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleLanguageChange {
    self.searchBar.placeholder = LocalizedString(@"search");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (self.searchController.isActive) {
        [self localizeCancelButton];
        [self localizeNoResultsText];
    }
#pragma clang diagnostic pop
}

// [优化] 强化取消按钮本地化逻辑，解决文案跳变 bug
- (void)localizeCancelButton {
    // 使用主线程异步，并配合一小段延时，确保在系统动画过程中及结束后都能捕捉到按钮
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyCancelButtonText];
        
        // 针对 iOS 6 动画可能导致的滞后，在 0.1 秒后进行二次校准
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self applyCancelButtonText];
        });
    });
}

// 内部遍历逻辑
- (void)applyCancelButtonText {
    for (UIView *view in self.searchBar.subviews) {
        // iOS 6 的搜索栏内部可能直接包含按钮，也可能在子视图的子视图里
        if ([view isKindOfClass:[UIButton class]]) {
            [(UIButton *)view setTitle:LocalizedString(@"cancel") forState:UIControlStateNormal];
        } else {
            for (UIView *subview in view.subviews) {
                if ([subview isKindOfClass:[UIButton class]]) {
                    [(UIButton *)subview setTitle:LocalizedString(@"cancel") forState:UIControlStateNormal];
                }
            }
        }
    }
}

- (void)localizeNoResultsText {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *v in self.searchController.searchResultsTableView.subviews) {
            if ([v isKindOfClass:[UILabel class]]) {
                ((UILabel *)v).text = LocalizedString(@"no_results");
            }
        }
    });
#pragma clang diagnostic pop
}

- (void)reloadSearchResults {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (self.searchController.isActive) {
        [self.searchController.searchResultsTableView reloadData];
    }
#pragma clang diagnostic pop
}

- (UIImage *)cachedImageForChannel:(Channel *)channel {
    NSString *logoKey = [channel logoIdentifier];
    return [self.imageCache objectForKey:logoKey];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredChannels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"SearchChannelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
    }
    
    Channel *ch = self.filteredChannels[indexPath.row];
    cell.textLabel.text = ch.name;
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    NSString *logoKey = [ch logoIdentifier];
    UIImage *cachedImage = [self.imageCache objectForKey:logoKey];
    
    if (cachedImage) {
        cell.imageView.image = cachedImage;
    } else {
        UIImage *defaultLogo = [UIImage generateDefaultLogoWithName:ch.name];
        cell.imageView.image = defaultLogo;
        
        if (ch.logo.length > 0) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *cleanURLStr = [ch.logo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSURL *url = [cleanURLStr toSafeURL];
                if (url) {
                    NSData *data = [[NetworkManager sharedManager] downloadDataSyncFromURL:url];
                    if (data) {
                        UIImage *downloadedImage = [UIImage imageWithData:data];
                        if (downloadedImage) {
                            UIImage *resizedImage = [downloadedImage resizeAndPadToSize:CGSizeMake(40, 40)];
                            [weakSelf.imageCache setObject:resizedImage forKey:logoKey];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (weakSelf && indexPath.row < weakSelf.filteredChannels.count) {
                                    Channel *currentChannel = weakSelf.filteredChannels[indexPath.row];
                                    NSString *currentLogoKey = [currentChannel logoIdentifier];
                                    if ([currentLogoKey isEqualToString:logoKey]) {
                                        UITableViewCell *updateCell = [tableView cellForRowAtIndexPath:indexPath];
                                        if (updateCell) {
                                            updateCell.imageView.image = resizedImage;
                                            [updateCell setNeedsLayout];
                                        }
                                    }
                                }
                            });
                        }
                    }
                }
            });
        } else {
            [self.imageCache setObject:defaultLogo forKey:logoKey];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Channel *ch = self.filteredChannels[indexPath.row];
    if ([self.delegate respondsToSelector:@selector(searchManager:didSelectChannel:)]) {
        [self.delegate searchManager:self didSelectChannel:ch];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    Channel *ch = self.filteredChannels[indexPath.row];
    if ([self.delegate respondsToSelector:@selector(searchManager:accessoryButtonTappedForChannel:)]) {
        [self.delegate searchManager:self accessoryButtonTappedForChannel:ch];
    }
}

#pragma mark - UISearchDisplayDelegate

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
    // 激活时立即调用一次
    [self localizeCancelButton];
}

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller {
    // [优化] 动画彻底结束后再次校准，确保万无一失
    [self localizeCancelButton];
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView {
    tableView.rowHeight = 55.0;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", searchString];
    self.filteredChannels = [self.sourceChannels filteredArrayUsingPredicate:predicate];
    
    // 每次重载数据时，覆盖“No Results”
    [self localizeNoResultsText];
    
    return YES;
}
#pragma clang diagnostic pop

@end