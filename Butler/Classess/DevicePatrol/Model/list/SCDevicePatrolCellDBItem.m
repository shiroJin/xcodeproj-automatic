//
//  SCDevicePatrolCellDBItem.m
//  Butler
//
//  Created by abeihaha on 16/8/28.
//  Copyright © 2016年 UAMA Inc. All rights reserved.
//

#import "SCDevicePatrolCellDBItem.h"
#import "SCDevicePatrolPointItem.h"
#import "SCDevicePatrolPanelItem.h"

@implementation SCDevicePatrolCellDBItem

@dynamic communityId;
@dynamic deviceID, name, serialNum, location, picUrl;
@dynamic patrolID, patrolDate, patrolSerialNum, chargerName, chargerMobile, patrolStatus, patrolType, sort;
@dynamic patrolPointJSON, patrolPanelJSON;
@dynamic executorId, executorUserName, executorUserMobile, chargerUserId, chargerUserName, chargerUserMobile;
#pragma mark  - Public Methods

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    return @{@"location":@"address",
             @"serialNum":@"deviceSerialNum"};
}

- (void)mj_keyValuesDidFinishConvertingToObject {
    // 数据解析完成后，把当前园区id赋值给对象
    self.communityId = [SCUser currentLoggedInUser].communityId;
}

- (NSAttributedString *)patrolStatusStr {
    NSString *str = @"";
    NSDictionary *attributes = nil;
    
    switch (self.patrolStatus) {
        case SCDevicePatrolStatusAll: {
            str = @"未知状态";
            attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:14.0f], NSForegroundColorAttributeName:[UIColor colorWithHexString:@"#A9A9A9"]};
            break;
        }
        case SCDevicePatrolStatusExpire: {
            str = @"超时未巡检";
            attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:14.0f], NSForegroundColorAttributeName:[UIColor colorWithHexString:@"#C5464A"]};
            break;
        }
        case SCDevicePatrolStatusWaiting: {
            str = @"待巡检";
            attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:14.0f], NSForegroundColorAttributeName:[UIColor colorWithHexString:@"#C5464A"]};
            break;
        }
        case SCDevicePatrolStatusProcessed: {
            str = @"已巡检";
            attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:14.0f], NSForegroundColorAttributeName:[UIColor colorWithHexString:@"#00AF09"]};
            break;
        }
        case SCDevicePatrolStatusUpload: {
            str = @"待上传";
            attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:14.0f], NSForegroundColorAttributeName:[UIColor colorWithHexString:@"#00AF09"]};
            break;
        }
        case SCDevicePatrolStatusInvalid: {
            str = @"已废弃";
            attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:14.0f], NSForegroundColorAttributeName:[UIColor colorWithHexString:@"#C5464A"]};
            break;
        }
    }
    return [[NSAttributedString alloc] initWithString:str attributes:attributes];
}

- (NSString *)patrolTypeStr {
    NSString *str = @"";
    switch (self.patrolType) {
        case SCDevicePatrolTypeAll: {
            str = @"未知";
            break;
        }
        case SCDevicePatrolTypeBLE: {
            str = @"蓝牙";
            break;
        }
        case SCDevicePatrolTypeQRCode: {
            str = @"二维码";
            break;
        }
        case SCDevicePatrolTypeNotBLE: {
            str = @"非蓝牙";
            break;
        }
    }
    return str;
}

- (NSString *)patrolDateStr {
    return [[NSString alloc] initWithFormat:@"巡检日期：%@",self.patrolDate];
}

- (NSArray *)patrolPointArray {
    if ([[self.patrolPointJSON trimAnySpace] length] == 0) {
        return nil;
    } else
        return [SCDevicePatrolPointItem mj_objectArrayWithKeyValuesArray:self.patrolPointJSON];
}

- (NSArray *)patrolPanelArray {
    if ([[self.patrolPanelJSON trimAnySpace] length] == 0) {
        return nil;
    } else
        return [SCDevicePatrolPanelItem mj_objectArrayWithKeyValuesArray:self.patrolPanelJSON];
}

- (BOOL)canExecute
{
    if ([self.executorId isEqualToString:[SCUser currentLoggedInUser].userId]) {
        return YES;
    }
    return NO;
}


#pragma mark - SRKObject Methods

+ (NSDictionary *)defaultValuesForEntity {
    return @{@"communityId":@"",
             @"deviceID":@"",
             @"name":@"",
             @"serialNum":@"",
             @"location":@"",
             @"patrolID":@"",
             @"patrolSerialNum":@"",
             @"patrolDate":@"",
             @"chargerName":@"",
             @"chargerMobile":@"",
             @"patrolPointJSON": @"",
             @"patrolPanelJSON" : @"",
             @"executorId": @"",
             @"executorUserMobile": @"",
             @"executorUserName": @"",
             @"chargerUserId": @"",
             @"chargerUserName": @"",
             @"chargerUserMobile": @""
    };
}

@end
