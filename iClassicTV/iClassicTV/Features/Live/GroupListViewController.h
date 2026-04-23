//
//  GroupListViewControllerTableViewController.h
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-21.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GroupListViewController : UITableViewController
@property (nonatomic, strong) NSArray *allChannels;
@property (nonatomic, strong) NSDictionary *groupedChannels;
@property (nonatomic, strong) NSArray *groupNames;

- (void)loadDataFromUserDefaults;
@end