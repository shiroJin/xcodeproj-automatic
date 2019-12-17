//
//  SCHomeScanQrcodeHelper.m
//  Butler
//
//  Created by zhanglijiong on 2018/1/17.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCHomeScanQrcodeHelper.h"

#import "CalendarHelper.h"
#import "NSDate+Ext.h"
#import "SCOfflineDataTimeManager.h"
// 抄表
#import "SCPanelMeterManager.h"
#import "SCPanelMeterOperateViewController.h"
#import "SCPanelMeterDetailViewController.h"
// 巡查
#import "SCPatrolManagerDetailViewController.h"
#import "SCPatrolManagerContentViewController.h"
#import "SCSelectPatrolManagerViewController.h"
#import "SCPatrolManager.h"
// 设施设备
#import "SCDeviceAccountManager.h"
#import "SCDeviceAccountItemViewController.h"
// 巡检
#import "SCDevicePatrolManager.h"
#import "SCDevicePatrolDetailViewController.h"
#import "SCDevicePatrolFBViewController.h"
// 维保
#import "SCDeviceMaintCellDBItem.h"
#import "SCDeviceMaintManager.h"
#import "SCDeviceMaintBeginViewController.h"
#import "SCDeviceMaintDetailViewController.h"

@interface SCHomeScanQrcodeHelper ()

// 巡查管理类
@property (strong, nonatomic) SCPatrolManager *patrolManager;
// 巡检管理类
@property (strong, nonatomic) SCDevicePatrolManager *devicePatrolManager;
// 抄表管理类
@property (strong, nonatomic) SCPanelMeterManager *panelMeterManager;
// 维保管理类
@property (strong, nonatomic) SCDeviceMaintManager *deviceMaintManager;

@end

@implementation SCHomeScanQrcodeHelper

- (SCPatrolManager *)patrolManager {
    if (!_patrolManager) {
        _patrolManager = [[SCPatrolManager alloc] init];
    }
    return _patrolManager;
}

- (SCDevicePatrolManager *)devicePatrolManager {
    if (!_devicePatrolManager) {
        _devicePatrolManager = [[SCDevicePatrolManager alloc] init];
    }
    return _devicePatrolManager;
}

- (SCPanelMeterManager *)panelMeterManager {
    if (!_panelMeterManager) {
        _panelMeterManager = [[SCPanelMeterManager alloc] init];
    }
    return _panelMeterManager;
}

- (SCDeviceMaintManager *)deviceMaintManager {
    if (!_deviceMaintManager) {
        _deviceMaintManager = [[SCDeviceMaintManager alloc] init];
    }
    return _deviceMaintManager;
}

#pragma mark - public
// 判断离线数据是否是当天最新更新的
- (BOOL)isLatestLTimeForModifiedTimeKey:(NSString *)TimeKey {
    NSString *lastModifiedTime = [[SCOfflineDataTimeManager manager] lastModifiedTimeForKey:TimeKey];
    if (lastModifiedTime.length > 0) {
        NSDate *lastModifiedDate = [CalendarHelper getDateFromString:lastModifiedTime withFormatter:@"yyyy-MM-dd  HH:mm:ss"];
        return [lastModifiedDate isToday];
    }
    return NO;
}

// 设施设备二维码的处理方法
- (void)deviceAccountQrcodeScanResult:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    // 设施设备使用老的逻辑
    [SCDeviceAccountManager fetchDeviceInfoWithQRCode:code success:^(SCDeviceAccountItem *item) {
        SCDeviceAccountItemViewController *vc = [[SCDeviceAccountItemViewController alloc] initWithNibName:NSStringFromClass([SCDeviceAccountItemViewController class]) bundle:nil];
        [vc setUpWithDeviceAccountItem:item];
        [controller.navigationController pushViewController:vc animated:YES];
    } failure:failureBlock];
}

// 扫一扫巡检二维码的处理方法
- (void)devicePatrolQrcodeScanResult:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    if ([self isLatestLTimeForModifiedTimeKey:kDevicePatrolDBUpdateTime]) {
        [self fetchOfflineDevicePatrolItemsForQrcode:code controller:controller failureBlock:failureBlock];
    } else {
        @weakify(self)
        [SCCommonHelper presentNetworkAlertViewController:controller title:@"下载设备巡检离线数据" doneBlock:^{
            controller.view.userInteractionEnabled = NO;
            [self.devicePatrolManager downLoadOfflineDevicePatrolDataInController:controller success:^{
                @strongify(self)
                controller.view.userInteractionEnabled = YES;
                [self fetchOfflineDevicePatrolItemsForQrcode:code controller:controller failureBlock:failureBlock];
            } failureBlock:^(NSError *error) {
                controller.view.userInteractionEnabled = YES;
                !failureBlock?:failureBlock(error);
            }];
        } canceBlock:failureBlock noNetWorkBlock:failureBlock];
    }
}

// 扫一扫维保二维码的处理方法
- (void)deviceMaintQrcodeScanResult:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    if ([self isLatestLTimeForModifiedTimeKey:kDeviceMaintDBUpdateTime]) {
        [self fetchOfflineDeviceMaintForQrcode:code controller:controller failureBlock:failureBlock];
    } else {
        @weakify(self)
        [SCCommonHelper presentNetworkAlertViewController:controller title:@"下载维保离线数据" doneBlock:^{
            @strongify(self)
            controller.view.userInteractionEnabled = NO;
            [self.deviceMaintManager downLoadOfflineDeviceMaintDataInController:controller success:^{
                controller.view.userInteractionEnabled = YES;
                [self fetchOfflineDeviceMaintForQrcode:code controller:controller failureBlock:failureBlock];
            } failureBlock:^(NSError *error) {
                controller.view.userInteractionEnabled = YES;
                !failureBlock?:failureBlock(error);
            }];
        } canceBlock:failureBlock noNetWorkBlock:failureBlock];
    }
}

// 扫一扫抄表二维码的处理方法
- (void)panelMeterQrcodeScanResult:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    if ([self isLatestLTimeForModifiedTimeKey:kPanelMeterDBUpdateTime]) {
        [self fetchOfflinePanelMeterForQrcode:code controller:controller failureBlock:failureBlock];
    } else {
        @weakify(self)
        [SCCommonHelper presentNetworkAlertViewController:controller title:@"下载抄表离线数据" doneBlock:^{
            controller.view.userInteractionEnabled = NO;
            [self.panelMeterManager downLoadOfflinePanelMeterDataInController:controller success:^{
                @strongify(self)
                controller.view.userInteractionEnabled = YES;
                [self fetchOfflinePanelMeterForQrcode:code controller:controller failureBlock:failureBlock];
            } failureBlock:^(NSError *error) {
                controller.view.userInteractionEnabled = YES;
                !failureBlock?:failureBlock(error);
            }];
        } canceBlock:failureBlock noNetWorkBlock:failureBlock];
    }
}

// 扫一扫巡查二维码的处理方法
- (void)patrolManagerQrcodeScanResult:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    if ([self isLatestLTimeForModifiedTimeKey:kPatrolManagerDBUpdateTime]) {
        [self fetchOfflinePatrolItemsForQrcode:code controller:controller failureBlock:failureBlock];
    } else {
        @weakify(self)
        [SCCommonHelper presentNetworkAlertViewController:controller title:@"下载巡查离线数据" doneBlock:^{
            controller.view.userInteractionEnabled = NO;
            [self.patrolManager downLoadOfflinePatrolManagerDataInController:controller success:^{
                @strongify(self)
                controller.view.userInteractionEnabled = YES;
                [self fetchOfflinePatrolItemsForQrcode:code controller:controller failureBlock:failureBlock];
            } failureBlock:^(NSError *error) {
                controller.view.userInteractionEnabled = YES;
                !failureBlock?:failureBlock(error);
            }];
        } canceBlock:failureBlock noNetWorkBlock:failureBlock];
    }
}

#pragma mark - private
// 查询设备巡检离线数据
- (void)fetchOfflineDevicePatrolItemsForQrcode:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    [SCDevicePatrolManager fetchDevicePatrolDBItemsWithQrcode:code success:^(SCDevicePatrolSectionDBItem *sectionsItem) {
        if (sectionsItem.items.count > 0) {
            // 巡检只考虑二维码组只会有一个设备
            SCDevicePatrolCellDBItem *cellItem = (SCDevicePatrolCellDBItem *)[sectionsItem.items firstObject];
            if (cellItem.patrolStatus == SCDevicePatrolStatusUpload) {
                NSString *msg = @"巡检已完成，请尽快上传巡检信息";
                NSError *error = [NSError errorWithDomain:SCApiErrorDomain code:SCApiErrorCodeFetchDataFailed userInfo:@{NSLocalizedDescriptionKey:msg}];
                !failureBlock?:failureBlock(error);
            } else if (cellItem.patrolStatus == SCDevicePatrolStatusProcessed)  {
                if ([[AFNetworkReachabilityManager sharedManager] isReachable]) {
                    // 有网时进入详情
                    SCDevicePatrolDetailViewController *detailVC = [[SCDevicePatrolDetailViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolDetailViewController class]) bundle:nil];
                    [detailVC setUpWithCellItem:cellItem];
                    [controller.navigationController pushViewController:detailVC animated:YES];
                } else {
                    NSString *msg = @"巡检已完成，请在有网情况下查看详情";
                    NSError *error = [NSError errorWithDomain:SCApiErrorDomain code:SCApiErrorCodeFetchDataFailed userInfo:@{NSLocalizedDescriptionKey:msg}];
                    !failureBlock?:failureBlock(error);
                }
            } else {
                SCDevicePatrolFBViewController *fbVC = [[SCDevicePatrolFBViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolFBViewController class]) bundle:nil];
                [fbVC setUpWithCellItem:cellItem inSectionItem:sectionsItem chage:^(SCDevicePatrolCellDBItem *item){}];
                [controller.navigationController pushViewController:fbVC animated:YES];
            }
        }
    } failureBlock:failureBlock];
}

// 查询抄表离线数据
- (void)fetchOfflinePanelMeterForQrcode:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    [SCPanelMeterManager fetchPanelMeterWithQrcode:code success:^(SCPanelMeterCellDBItem *item) {
        if (item.meterStatus == SCPanelMeterStatusUpload) {
            NSString *msg = @"仪表已抄表，请尽快上传抄表信息。";
            NSError *error = [NSError errorWithDomain:SCApiErrorDomain code:SCApiErrorCodeFetchDataFailed userInfo:@{NSLocalizedDescriptionKey:msg}];
            !failureBlock?:failureBlock(error);
        } else if (item.meterStatus == SCPanelMeterStatusFinish) {
            SCPanelMeterDetailViewController *detailVC = [[SCPanelMeterDetailViewController alloc] initWithNibName:NSStringFromClass([SCPanelMeterDetailViewController class]) bundle:nil];
            [detailVC setUpWithPanelMeterCellDBItem:item];
            [controller.navigationController pushViewController:detailVC animated:YES];
        } else {
            SCPanelMeterOperateViewController *operateVC = [[SCPanelMeterOperateViewController alloc] initWithNibName:[SCPanelMeterOperateViewController sc_className] bundle:nil];
            [operateVC setUpWithPanelMeterCellDBItem:item finish:^(SCPanelMeterCellDBItem *item) {}];
            [controller.navigationController pushViewController:operateVC animated:YES];
        }
    } failureBlock:failureBlock];
}

// 查询维保离线数据
- (void)fetchOfflineDeviceMaintForQrcode:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    [SCDeviceMaintManager fetchDeviceMaintDBItemsWithQrcode:code success:^(SCDeviceMaintCellDBItem *item) {
        if (item.maintStatus == SCDeviceMaintStatusUpload) {
            // 待上传
            NSString *msg = @"设备已维保，请尽快上传维保信息。";
            NSError *error = [NSError errorWithDomain:SCApiErrorDomain code:SCApiErrorCodeFetchDataFailed userInfo:@{NSLocalizedDescriptionKey:msg}];
            !failureBlock?:failureBlock(error);
        } else if (item.maintStatus == SCDeviceMaintStatusInvalid) {
            // 已作废
            NSString *msg = @"设备维保任务已作废。";
            NSError *error = [NSError errorWithDomain:SCApiErrorDomain code:SCApiErrorCodeFetchDataFailed userInfo:@{NSLocalizedDescriptionKey:msg}];
            !failureBlock?:failureBlock(error);
        } else if (item.maintStatus == SCDeviceMaintStatusProcessed) {
            // 已维保
            SCDeviceMaintDetailViewController *vc = [[SCDeviceMaintDetailViewController alloc] initWithNibName:NSStringFromClass([SCDeviceMaintDetailViewController class]) bundle:nil];
            [vc setUpWithMaintID:item.maintID deviceID:item.deviceID deviceName:item.name itemDisplay:YES];
            [controller.navigationController pushViewController:vc animated:YES];
        } else {
            SCDeviceMaintBeginViewController *vc = [[SCDeviceMaintBeginViewController alloc] initWithNibName:NSStringFromClass([SCDeviceMaintBeginViewController class]) bundle:nil];
            vc.isScanGoto = YES;
            [vc setUpWithItem:item change:^(SCDeviceMaintCellDBItem *item) {}];
            [controller.navigationController pushViewController:vc animated:YES];
        }
    } failureBlock:failureBlock];
}

// 查询巡查离线数据
- (void)fetchOfflinePatrolItemsForQrcode:(NSString *)code controller:(UIViewController *)controller failureBlock:(void(^)(NSError *error))failureBlock {
    [SCPatrolManager fetchPatrolManagerDBItemsWithQrcode:code success:^(SCPatrolManagerSectionDBItem *sectionsItem) {
        if (sectionsItem.items.count == 1) {
            // 当只有一个的时候，直接进详情页
            SCPatrolManagerCellDBItem *cellItem = (SCPatrolManagerCellDBItem *)[sectionsItem.items firstObject];
            if (cellItem.inspectStatus == SCPatrolManagerStatusUpload) {
                NSString *msg = @"巡查已完成，请尽快上传巡查信息";
                NSError *error = [NSError errorWithDomain:SCApiErrorDomain code:SCApiErrorCodeFetchDataFailed userInfo:@{NSLocalizedDescriptionKey:msg}];
                !failureBlock?:failureBlock(error);
            } else if (cellItem.inspectStatus == SCPatrolManagerStatusProcessed)  {
                if ([[AFNetworkReachabilityManager sharedManager] isReachable]) {
                    // 有网时进入详情
                    SCPatrolManagerDetailViewController *detailVC = [[SCPatrolManagerDetailViewController alloc] initWithNibName:NSStringFromClass([SCPatrolManagerDetailViewController class]) bundle:nil];
                    [detailVC setUpWithCellItem:cellItem];
                    [controller.navigationController pushViewController:detailVC animated:YES];
                } else {
                    NSString *msg = @"巡查任务已完成，请在有网情况下查看详情";
                    NSError *error = [NSError errorWithDomain:SCApiErrorDomain code:SCApiErrorCodeFetchDataFailed userInfo:@{NSLocalizedDescriptionKey:msg}];
                    !failureBlock?:failureBlock(error);
                }
            } else {
                SCPatrolManagerContentViewController *contentVC = [[SCPatrolManagerContentViewController alloc]initWithStyle:UITableViewStyleGrouped];
                cellItem.inspectMethod = SCDevicePatrolTypeQRCode;
                // 加上最近完成时间
                cellItem.lastEndTimeModel = [SCPatrolManager inspectPointIdForLastEndTime:cellItem.inspectPointId];
                [contentVC setUpWithCellItem:cellItem
                               inSectionItem:sectionsItem
                                       chage:^(SCPatrolManagerCellDBItem *item) {}];
                [controller.navigationController pushViewController:contentVC animated:YES];
            }
        } else {
            // 当多个的时候，进列表页
            SCSelectPatrolManagerViewController *selectVC = [[SCSelectPatrolManagerViewController alloc]initWithNibName:[SCSelectPatrolManagerViewController sc_className] bundle:nil];
            [selectVC setUpWithPatrolSectionItem:sectionsItem inspectMethod:SCDevicePatrolTypeQRCode change:^(SCPatrolManagerSectionDBItem *item) {}];
            [controller.navigationController pushViewController:selectVC animated:YES];
        }
    } failureBlock:failureBlock];
}

@end
