//
//  SCDevicePatrolUploadItem.m
//  Butler
//
//  Created by abeihaha on 16/8/6.
//  Copyright © 2016年 UAMA Inc. All rights reserved.
//

#import "SCDevicePatrolUploadItem.h"
#import "SCDevicePatrolCellDBItem.h"
#import "SRKObject+SCHandler.h"

@implementation SCDevicePatrolUploadItem

@dynamic communityId;
@dynamic deviceName, serialNum, patrolDate, createTime;
@dynamic patrolID, deviceID, imgNames, patrolType, remark, panelContent;

#pragma mark - Public Methods

- (NSArray *)photoNames {
    if ([[self.imgNames trim] length] > 0) {
        return [self.imgNames componentsSeparatedByString:@","];
    }
    return nil;
}

- (id)initWithDevicePatrolCellDBItem:(SCDevicePatrolCellDBItem *)item
                          createTime:(NSString *)createTime
                              remark:(NSString *)remark
                        panelContent:(NSString *)panelContent
                            imgNames:(NSString *)imgNames {
    if (self = [super init]) {
        self.communityId = item.communityId;
        self.deviceName = item.name;
        self.serialNum = item.serialNum;
        self.patrolDate = item.patrolDate;
        self.patrolID = item.patrolID;
        self.deviceID = item.deviceID;
        self.patrolType = item.patrolType;
        self.createTime = createTime;
        self.remark = remark;
        self.panelContent = panelContent;
        self.imgNames = imgNames;
    }
    return self;
}

- (void)uploadSuccessHandler {
    SRKResultSet *items = [[[SCDevicePatrolCellDBItem query]
                            whereWithFormat:@"patrolID = %@ AND deviceID = %@"
                            withParameters:@[self.patrolID, self.deviceID]]
                           fetch];
    if ([items count] > 0) {
        SCDevicePatrolCellDBItem *dbItem = items[0];
        if (dbItem) {
            dbItem.patrolStatus = SCDevicePatrolStatusProcessed;
            [dbItem commit];
        }
    }
}

- (BOOL)deleteHandler {
    if ([self deleteWithType:SCUploadItemTypeDevicePatrol]) {
        SRKResultSet *items = [[[SCDevicePatrolCellDBItem query]
                                whereWithFormat:@"patrolID = %@ AND deviceID = %@"
                                withParameters:@[self.patrolID, self.deviceID]]
                               fetch];
        if ([items count] > 0) {
            SCDevicePatrolCellDBItem *dbItem = items[0];
            if (dbItem) {
                dbItem.patrolStatus = SCDevicePatrolStatusWaiting;
                if ([dbItem commit]) {
                    return YES;
                }
            }
        }
        return YES;
    }
    return NO;
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

#pragma mark - SRKObject Methods

+ (NSArray*)ignoredProperties {
    return @[@"images"];
}

+ (NSDictionary*)defaultValuesForEntity {
    return @{@"communityId": @"",
             @"deviceName": @"",
             @"serialNum": @"",
             @"patrolDate": @"",
             @"createTime":@"",
             @"patrolID":@"",
             @"deviceID":@"",
             @"remark":@"巡检结果：已完成巡检。",
             @"imgNames": @"",
             @"panelContent": @""};
}

+ (SRKIndexDefinition *)indexDefinitionForEntity {
    SRKIndexDefinition* idx = [SRKIndexDefinition new];
    [idx addIndexForProperty:@"createTime" propertyOrder:SRKIndexSortOrderAscending];
    return idx;
}

@end
