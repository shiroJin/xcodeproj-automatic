//
//  SCInterContactsCell.h
//  Butler
//
//  Created by quanbinjin on 2018/8/13.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//  

#import <UIKit/UIKit.h>
@class SCContactModel;

@interface SCInterContactsCell : UITableViewCell

- (void)setupWithContact:(SCContactModel *)contact keyWord:(NSString *)keyWord;

@end
