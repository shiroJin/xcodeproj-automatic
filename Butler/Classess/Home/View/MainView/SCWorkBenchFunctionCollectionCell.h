//
//  SCWorkBenchFunctionCollectionCell.h
//  Butler
//
//  Created by zhanglijiong on 2018/6/19.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//  工作台首页功能的cell

#import <UIKit/UIKit.h>

@class SCMenuItem;

// item的大小
extern CGSize SCFunctionCollectionCellSize(void);

@interface SCWorkBenchFunctionCollectionCell : UICollectionViewCell

@property (strong, nonatomic) SCMenuItem *item;

@end
