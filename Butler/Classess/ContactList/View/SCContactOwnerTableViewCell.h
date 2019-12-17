//
//  SCContactOwnerTableViewCell.h
//  Butler
//
//  Created by quanbinjin on 2018/8/14.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SCContactOwner;

@interface SCContactOwnerTableViewCell : UITableViewCell

- (void)setupWithOwner:(SCContactOwner *)owner;

@end
