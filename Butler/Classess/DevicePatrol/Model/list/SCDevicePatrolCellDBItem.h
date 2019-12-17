//
//  SCDevicePatrolCellDBItem.h
//  Butler
//
//  Created by abeihaha on 16/8/28.
//  Copyright © 2016年 UAMA Inc. All rights reserved.
//  设备巡检离线数据设备单元数据结构

#import <SharkORM/SharkORM.h>

@interface SCDevicePatrolCellDBItem : SRKObject

// 园区id
@property (copy, nonatomic) NSString *communityId;
// 巡检状态，1-待巡检，2-已巡检，3-超时未巡检
@property (assign, nonatomic) SCDevicePatrolStatus patrolStatus;
// 巡检方式
@property (assign, nonatomic) SCDevicePatrolType patrolType;
// 排序字段，0-超时未巡检，1-待巡检，2-已完成
@property (assign, nonatomic) NSInteger sort;

// 设备ID
@property (copy, nonatomic) NSString *deviceID;
// 设备名称
@property (copy, nonatomic) NSString *name;
// 设备编号
@property (copy, nonatomic) NSString *serialNum;
// 设备位置
@property (copy, nonatomic) NSString *location;
// 设备封面图
@property (copy, nonatomic) NSString *picUrl;

// 巡检ID
@property (copy, nonatomic) NSString *patrolID;
// 巡检编号
@property (copy, nonatomic) NSString *patrolSerialNum;
// 巡检日期
@property (copy, nonatomic) NSString *patrolDate;
// 负责人姓名
@property (copy, nonatomic) NSString *chargerName;
// 负责人电话
@property (copy, nonatomic) NSString *chargerMobile;

/// 计划执行人Id
@property (copy, nonatomic) NSString *executorId;
/// 计划执行人name
@property (copy, nonatomic) NSString *executorUserName;
/// 计划执行人phone
@property (copy, nonatomic) NSString *executorUserMobile;
/// 巡检负责人id
@property (copy, nonatomic) NSString *chargerUserId;
/// 巡检负责人电话
@property (copy, nonatomic) NSString *chargerUserMobile;
/// 巡检负责人姓名
@property (copy, nonatomic) NSString *chargerUserName;

// 巡检要点数组的JSONString
@property (copy, nonatomic) NSString *patrolPointJSON;
// 巡检查表数组的JSONString
@property (copy, nonatomic) NSString *patrolPanelJSON;

//本地使用
@property (assign, nonatomic) BOOL selected;

//calculate properties
- (NSAttributedString *)patrolStatusStr;
- (NSString *)patrolTypeStr;
- (NSString *)patrolDateStr;
- (NSArray *)patrolPointArray;
- (NSArray *)patrolPanelArray;

- (BOOL)canExecute;

@end
