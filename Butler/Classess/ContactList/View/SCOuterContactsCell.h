//
//  SCOuterContactsCell.h
//  Butler
//
//  Created by quanbinjin on 2018/8/15.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCContactModel.h"

@interface SCOuterContactsCell : UITableViewCell

- (void)setupWithContact:(SCContactModel *)contact keyWord:(NSString *)keyWord;

@end
