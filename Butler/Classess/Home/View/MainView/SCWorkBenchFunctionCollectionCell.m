//
//  SCWorkBenchFunctionCollectionCell.m
//  Butler
//
//  Created by zhanglijiong on 2018/6/19.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCWorkBenchFunctionCollectionCell.h"

#import "SCMenuItem.h"
#import <UIImageView+WebCache.h>

CGSize SCFunctionCollectionCellSize(void) {
    return CGSizeMake(64, 60);
}

@interface SCWorkBenchFunctionCollectionCell ()


@property (weak, nonatomic) IBOutlet UIImageView *functionImageView;
@property (weak, nonatomic) IBOutlet UILabel *functionNameLabel;

@end

@implementation SCWorkBenchFunctionCollectionCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setItem:(SCMenuItem *)item {
    _item = item;
    
    if (item.isAllServiceItem) {
        [self.functionImageView setImage:[UIImage imageNamed:@"allFunction"]];
    } else {
        [self.functionImageView sd_setImageWithURL:[NSURL URLWithString:item.imgUrl] placeholderImage:[UIImage imageNamed:@"menuitem_default"]];
    }
    self.functionNameLabel.text = item.title;
}

@end
