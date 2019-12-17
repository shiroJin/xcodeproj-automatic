//
//  SCOuterContactsCell.m
//  Butler
//
//  Created by quanbinjin on 2018/8/15.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCOuterContactsCell.h"

@interface SCOuterContactsCell ()

@property (weak, nonatomic) IBOutlet UILabel *nameLbl;
@property (weak, nonatomic) IBOutlet UILabel *roleLbl;
@property (weak, nonatomic) IBOutlet UILabel *phoneNumLbl;

@end

@implementation SCOuterContactsCell

- (void)setupWithContact:(SCContactModel *)contact keyWord:(NSString *)keyWord {
    _nameLbl.attributedText = [ISNULL(contact.userName) highlightStringWithKeyWord:ISNULL(keyWord)];
    _roleLbl.text = ISNULL(contact.roleName).length == 0 ? @" " : contact.roleName;;
    _phoneNumLbl.text = [self phoneNumFormat:contact.mobileNum];
}

- (NSString *)phoneNumFormat:(NSString *)phoneNum {
    if (phoneNum.length == 11) {
        NSString *format = [phoneNum stringByReplacingCharactersInRange:NSMakeRange(3, 4) withString:@"****"];
        return format;
    } else {
        return @"";
    }
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
