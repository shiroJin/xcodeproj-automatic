//
//  SCContactOwnerTableViewCell.m
//  Butler
//
//  Created by quanbinjin on 2018/8/14.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCContactOwnerTableViewCell.h"
#import "SCContactOwner.h"

@interface SCContactOwnerTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *nameLbl;
@property (weak, nonatomic) IBOutlet UILabel *addressLbl;
@property (weak, nonatomic) IBOutlet UILabel *phoneNumLbl;
@property (weak, nonatomic) IBOutlet UILabel *secondAddressLbl;

@end

@implementation SCContactOwnerTableViewCell

- (void)setupWithOwner:(SCContactOwner *)owner {
    _nameLbl.text = ISNULL(owner.userName);
    _phoneNumLbl.text = [self phoneNumFormat:owner.mobileNum];
    _addressLbl.text = owner.addressList.firstObject;
    if (owner.addressList.count > 1) {
        _secondAddressLbl.text = owner.addressList[1];
    } else {
        _secondAddressLbl.text = @"";
    }
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
