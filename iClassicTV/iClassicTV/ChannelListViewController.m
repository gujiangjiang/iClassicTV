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

@interface ChannelListViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) Channel *selectedChannel;
@end
@implementation ChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 频道列表使用 Plain 样式更符合 iOS 6 习惯
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"ChannelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        // 使用 Subtitle 样式，可以显示“线路数量”或分辨率
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // 优化：文字颜色
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    }
    
    Channel *ch = self.channels[indexPath.row];
    cell.textLabel.text = ch.name;
    
    // 针对你的 4K 需求进行 UI 优化
    if ([ch.name rangeOfString:@"4K" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0]; // 红色高亮 4K
    } else {
        cell.textLabel.textColor = [UIColor blackColor];
    }
    
    if (ch.urls.count > 1) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"包含 %lu 条线路", (unsigned long)ch.urls.count];
    } else {
        cell.detailTextLabel.text = @"标准线路";
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.selectedChannel = self.channels[indexPath.row];
    
    if (self.selectedChannel.urls.count > 1) {
        // 多源合并优化：弹出原生底部菜单让用户选线路
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"选择 %@ 的播放线路", self.selectedChannel.name]
                                                           delegate:self
                                                  cancelButtonTitle:@"取消"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:nil];
        for (int i = 0; i < self.selectedChannel.urls.count; i++) {
            [sheet addButtonWithTitle:[NSString stringWithFormat:@"线路 %d", i + 1]];
        }
        [sheet showInView:self.view];
    } else {
        [self playVideoWithURL:self.selectedChannel.urls[0]];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    // 第一个按钮是取消，所以其他按钮的 index 要调整
    NSInteger sourceIndex = buttonIndex - 1;
    [self playVideoWithURL:self.selectedChannel.urls[sourceIndex]];
}

- (void)playVideoWithURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    MPMoviePlayerViewController *playerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
    // 使用全屏模态弹出原生播放器
    [self presentMoviePlayerViewControllerAnimated:playerVC];
}

@end