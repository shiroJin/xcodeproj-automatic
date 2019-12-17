//
//  SCInterContactsCell.m
//  Butler
//
//  Created by quanbinjin on 2018/8/13.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCInterContactsCell.h"
#import "SCContactModel.h"

@interface SCInterContactsCell ()

@property (weak, nonatomic) IBOutlet UIImageView *portraitView;
@property (weak, nonatomic) IBOutlet UILabel *nameLbl;
@property (weak, nonatomic) IBOutlet UILabel *workLbl;
@property (weak, nonatomic) IBOutlet UILabel *phoneNumLbl;

@end

@implementation SCInterContactsCell

- (void)setupWithContact:(SCContactModel *)contact keyWord:(NSString *)keyWord {
    [_portraitView sd_setImageWithURL:[NSURL URLWithString:contact.headPicName] placeholderImage:[UIImage imageNamed:@"contacts_portrait"]];
    _nameLbl.attributedText = [ISNULL(contact.userName) highlightStringWithKeyWord:ISNULL(keyWord)];
    _workLbl.text = ISNULL(contact.roleName).length == 0 ? @"暂无角色" : contact.roleName;
    _phoneNumLbl.text = [self phoneNumFormat:contact.mobileNum];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
    _portraitView.layer.cornerRadius = 20.f;
    _portraitView.layer.masksToBounds = YES;
}

- (NSString *)phoneNumFormat:(NSString *)phoneNum {
    if (phoneNum.length == 11) {
        NSString *format = [phoneNum stringByReplacingCharactersInRange:NSMakeRange(3, 4) withString:@"****"];
        return format;
    } else {
        return @"";
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
