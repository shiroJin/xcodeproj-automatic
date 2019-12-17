//
//  SCMenuItemManager.m
//  Butler
//
//  Created by zhanglijiong on 2018/6/25.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCMenuItemManager.h"
#import "SCCommunityInfo.h"
#import "SCMenuItem.h"
#import "SCGlobalDataManager.h"
#import "SCLocationCommunityManager.h"
#import "SCLeaderViewController.h"
#import "SCWebViewController.h"
#import "SCNetworkConfig.h"
#import "SCCallFunctionHelper.h"
#import "SCRoomNumSelectViewController.h"
#import "SCSelectProjectController.h"
#import "SCSelectProjectSearchController.h"
#import "SCAddReportContentViewController.h"
#import "SCAddGroupReportViewController.h"
#import "SCBaseWebViewController.h"

@interface SCMenuItemManager ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, SCMenuItem *> *supMenuItemDict;
// 本地的全部应用数据
@property (nonatomic, strong) NSMutableDictionary<NSString *, SCMenuItem *> *locMenuItemDict;

@end

@implementation SCMenuItemManager

+ (instancetype)sharedInstance {
    static SCMenuItemManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SCMenuItemManager alloc] init];
    });
    return manager;
}

- (id)init {
    if (self = [super init]) {
        self.supMenuItemDict = [NSMutableDictionary new];
        self.locMenuItemDict = [NSMutableDictionary new];
        [self configMenuItemDict];
    }
    return self;
}

- (NSMutableArray<SCMenuItem *> *)handleServiceMenuItems:(NSArray<SCMenuItem *> *)servierItems {
    NSMutableArray *resultItems = [NSMutableArray new];
    for (SCMenuItem *item in servierItems) {
        // 把对应code的本地配置赋值给item对象
        SCMenuItem *locationItem = self.locMenuItemDict[item.code];
        if (locationItem) {
            item.nib = locationItem.nib;
            item.controller = locationItem.controller;
            item.enable = locationItem.enable;
            [self.supMenuItemDict setValue:item forKey:item.code];
        }
        [resultItems addObject:item];
    }
    return resultItems;
}

- (void)menuItemSelectedHandle:(SCMenuItem *)item onController:(UIViewController *)controller {
    // 先判断逻辑
    if ([controller isKindOfClass:[SCSelectProjectController class]] || [controller isKindOfClass:[SCSelectProjectSearchController class]]) {
        // 如果本身就是中间页了，就直接执行跳转
        [self jumpToMenuItemController:item onController:controller];
    } else {
        if ([SCUser currentLoggedInUser].switchType == SCAddressSwitchTypeProject) {
            [self jumpToMenuItemController:item onController:controller];
        } else {
            // 选择的不是项目，则需要判断是否需要重新定位
            if ([[SCLocationCommunityManager sharedInstance] isRepeatLocation]) {
                SCSelectProjectController *VC = [[SCSelectProjectController alloc] initWithNibName:[SCSelectProjectController sc_className] bundle:nil];
                VC.menuItem = item;
                [controller.navigationController pushViewController:VC animated:YES];
            } else {
                // 进入模块前默认配置本地缓存的园区信息
                SCCommunityInfo *community = [SCLocationCommunityManager sharedInstance].cacheCommunity;
                [SCUser currentLoggedInUser].communityId = community.communityId;
                [SCUser currentLoggedInUser].communityName = community.communityName;
                [[SCNetworkConfig netWorkConfig] configDefaultCommunityId:community.communityId];
                [self jumpToMenuItemController:item onController:controller];
            }
        }
    }
}

// 具体的跳转方法
- (void)jumpToMenuItemController:(SCMenuItem *)item onController:(UIViewController *)controller {
    
    [SCUser currentLoggedInUser].code = item.code;
    
    NSString *controllerName = [item controller];
    NSString *nibName = item.nib;
    // 目前不支持UIStoryboard的控制器跳转
    if (controllerName.length > 0 && nibName.length > 0) {
        // 有controller和有nib, 有些需要特殊处理
        NSString *lastNibName = [self gainNibNameWithSelectItem:item];
        UIViewController *vc = [[NSClassFromString(lastNibName) alloc] initWithNibName:lastNibName bundle:nil];
        // 领导视图的传个值
        if ([controllerName isEqualToString:@"SCLeaderViewController"]) {
            ((SCLeaderViewController *)vc).menuItem = item;
        }
        // 装修登记
        if ([item.code integerValue] == SCMenuItemCodeDecorationSign) {
            /// 装修登记的特殊处理
            vc.title = @"选择装修申请业主";
            ((SCRoomNumSelectViewController *)vc).choseType = SCChoseRoomTypeDecoration;
        }
        // 新增报事
        if ([item.code integerValue] == SCMenuItemCodeAddReport) {
            if ([SCUser currentLoggedInUser].userType == SCUserTypeCommunityAdmin) {
                ((SCAddReportContentViewController *)vc).menuItem = item;
            } else {
                ((SCAddGroupReportViewController *)vc).menuItem = item;
            }
        }
        
        [controller.navigationController pushViewController:vc animated:YES];
    } else if (controllerName.length > 0 ) {
        // 有controller和没有nib
        UIViewController *vc = [[NSClassFromString(controllerName) alloc] init];
        
        if (item.code.integerValue == SCMenuItemCodeH5CommunityPaymentAccess) { // H5园区缴费
            ((SCBaseWebViewController *)vc).urlString = [kDistributioneBaseCommonUrl stringByAppendingString:kCommunityPaymentH5UrlString];
            ((SCBaseWebViewController *)vc).needJointParams = YES;
        }
        
        [controller.navigationController pushViewController:vc animated:YES];
    } else {
        // 没有controller和没有nib
        /// 虚拟管家
        if([item.code integerValue] == SCMenuItemCodeVirtualKeeper) {
            /// 是管家身份，则跳转到虚拟管家拨号页面
            BOOL isSteward = [SCGlobalDataManager sharedInstance].isSteward;
            if (isSteward) {
                [[SCCallFunctionHelper shareInstance] startCallFunctionWith:controller callNumber:nil showError:YES completionHandler:^(BOOL success) {
                    
                }];
            }
        } else if ([item.code integerValue] == SCMenuItemCodeWIFI) {
            NSString *urlString = [NSString stringWithFormat:@"%@%@", kConfigBaseUrl(SCURLTypeWeb), kParkWIFIUrlString];
            SCWebViewController *webController = [[SCWebViewController alloc] initWithURL:[NSURL URLWithString:urlString]];
            [controller.navigationController pushViewController:webController animated:YES];
        } else {
            /// 其他情况，弹出alert提示
            [self showWarningAlert:controller];
        }
    }
}


/// 处理点击一个应用，储存相关（sharkorm不能满足这个使用，不能使用）
+ (void)dealWithServiceSelectedWithModel:(SCMenuItem *)model {
    
    if (!model) {
        return;
    }
    
    SCMenuItemCode codeType = [model.code integerValue];
    
    if (codeType == SCMenuItemCodeAddReport
        || codeType == SCMenuItemCodeDepositSign
        || codeType == SCMenuItemCodeDecorationSign
        || codeType == SCMenuItemCodeHomeScan) {
        /// 本地自定义模块，不记录
        return;
    }
    
    /// 取到本地缓存
    NSMutableArray *tempLocalArray = [SCMenuItem gainAllLocalServicesData];
    /// mutableCopy 防止数据污染
    NSMutableArray *tempLocalArr = [tempLocalArray mutableCopy];
    [tempLocalArr enumerateObjectsUsingBlock:^(SCMenuItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([ISNULL(model.code) isEqualToString:ISNULL(obj.code)])  {
            /// 代表本地已有相等，移除掉
            [tempLocalArray removeObject:obj];
            *stop = YES;
        }
    }];
    
    /// 插入最前
    [tempLocalArray insertObject:model atIndex:0];
    
    if (tempLocalArray.count > 9) {
        /// 大于9，就移除最后一个(理论上不会大于10)
        [tempLocalArray removeLastObject];
    }
    
    BOOL success = [SCMenuItem saveServicesData:tempLocalArray];
    NSLog(@"保存最近使用数据==%@==",(success ? @"成功" : @"失败"));
}

#pragma mark - private method
// 配置功能模块的控制器信息
- (void)configMenuItemDict {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSMutableArray *menuItems = [self configMenuItemControllers];
    for (SCMenuItem *item in menuItems) {
        [dict setValue:item forKey:item.code];
    }
    self.locMenuItemDict = [dict mutableCopy];
}

// 本地配置的功能模块信息
- (NSMutableArray *)configMenuItemControllers {
    NSMutableArray *menuItems = [NSMutableArray new];
    
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeVisitorQuery, @"访客查询", @"SCVisitorQueryController", @"SCVisitorQueryController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeCarSign, @"车访登记", @"SCCarSignMainController", @"SCCarSignMainController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeCarManager, @"车辆管理", @"SCCarSearchViewController", @"SCCarSearchViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeExpRecord, @"快递记录", @"SCExpRecordListViewController", @"SCExpRecordListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeServiceOrder, @"服务工单", @"SCServiceOrderListController", @"SCServiceOrderListController", YES)];
    
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeActivitySign, @"活动签到", @"SCActivityMainListController", @"SCActivityMainListController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeDeposit, @"物品寄存", @"SCDepositListViewController", @"SCDepositListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodePersonSign, @"人行登记", @"SCPersonSignMainController", @"SCPersonSignMainController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeMineServiceOrder, @"我的工单", @"SCMineOrderListViewController", @"SCMineOrderListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeOwnerQuery, @"业主查询", @"SCOwnerSearchListController", @"SCOwnerSearchListController", YES)];
    
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeEagleMonitor, @"鹰眼监控", @"SCEagleMonitorListViewController", @"SCEagleMonitorListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeOperating, @"运营统计", @"", nil, YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeReportManager, @"报事管理", @"SCReportListViewController", @"SCReportListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeLeaderView, @"领导视图", @"SCLeaderViewController", @"SCLeaderViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeDeviceAccount, @"设施设备", @"SCDeviceAccountListViewController", @"SCDeviceAccountListViewController", YES)];
    
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeDevicePatrol, @"设备巡检", @"SCDevicePatrolViewController", @"SCDevicePatrolViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeDeviceMaint, @"设备维保", @"SCDeviceMaintListViewController", @"SCDeviceMaintListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodePanelMeter, @"仪表抄表", @"SCPanelMeterManagerMainController", @"SCPanelMeterManagerMainController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeDecorationManager, @"装修管理", @"SCDecorationManagerListController", @"SCDecorationManagerListController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeVirtualKeeper, @"虚拟管家", @"", nil, YES)];
    
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeCarParking, @"共享车位", @"SCParkingListViewController", @"SCParkingListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeCarParkManager, @"共享停车", @"SCCarParkManagerViewController", @"SCCarParkManagerViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeElectronicPatrol, @"电子巡更", @"SCElectronicPatrolController", @"SCElectronicPatrolController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodePatrolManager, @"巡查管理", @"SCPatrolManagerMainController", @"SCPatrolManagerMainController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeWIFI, @"园区WIFI", @"", nil, YES)];
    
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeNameCertification, @"实名认证", @"SCNameCertificationListController", @"SCNameCertificationListController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeOwnerManager, @"业主管理", @"SCOwnerManagerMainController", @"SCOwnerManagerMainController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeSmartDoor, @"智能开门", @"SCRemainSmartDoorOpenViewController", @"SCRemainSmartDoorOpenViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeItemView, @"项目视图", @"SCLeaderViewController", @"SCLeaderViewController", YES)];
    // 小邑特殊模块
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeHotActivity, @"热门活动", @"SCOfflineActivityListController", @"SCOfflineActivityListController", YES)];
    
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeBusinessOrder, @"授权订单", @"SCBusinessOrderListController", @"SCBusinessOrderListController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodePropertyChooseRoom, @"生活缴费", @"SCPropertyChooseRoomController", @"SCPropertyChooseRoomController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeMyBusinessOrder, @"我的订单", @"SCMyBusinessOrderListViewController", @"SCMyBusinessOrderListViewController", YES)];
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeItemCustomerGather, @"客户采集", @"SCCustomerGatherController", @"SCCustomerGatherController", YES)];
    /// 云助2.0 add by xg
    /// 扫码核销
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeScanWriteOffOrder, @"订单核销", @"SCWriteOffOrderListController", @"SCWriteOffOrderListController", YES)];
    /// 停车申请
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeParkApply, @"停车申请", @"SCParkApplyMainController", @"SCParkApplyMainController", YES)];
    /// 场地预订
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodePlaceBook, @"场地预订", @"SCPlaceBookListController", @"SCPlaceBookListController", YES)];
    /// 资讯
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeCommunityNews, @"园区资讯", @"SCInfoContainerViewController", @"SCInfoContainerViewController", YES)];
    /// 空间资产
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeBuildingAssets, @"空间资产", @"SCRoomAssetsViewController", @"SCRoomAssetsViewController", YES)];
    /// 物品出门
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeGoodsAccess, @"物品出门", @"SCGoodsAccessListController", @"SCGoodsAccessListController", YES)];
    /// 物品借用
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeGoodsBorrow, @"物品借用", @"SCGoodsBorrowViewContainer", @"SCGoodsBorrowViewContainer", YES)];

    /// H5园区缴费
    [menuItems addObject:SCCreateMenuItem(SCMenuItemCodeH5CommunityPaymentAccess, @"项目缴费", @"SCBaseWebViewController", nil, YES)];
    
    return menuItems;
}

/// 根据模块权限获取模块nibName
- (NSString *)gainNibNameWithSelectItem:(SCMenuItem *)item {
    NSString *nibName = item.nib;
    /// 车访登记，权限的判断
    if ([item.code integerValue] == SCMenuItemCodeCarSign) {
        if (![SCGlobalDataManager sharedInstance].isOCREnable) {
            /// 没有车牌扫描权限，进入手动输入页面
            nibName = @"SCAddCarSignController";
        }
    }
    /// 人访登记，权限的判断
    if ([item.code integerValue] == SCMenuItemCodePersonSign) {
        if (![SCGlobalDataManager sharedInstance].isIDScanEnable) {
            /// 没有身份证扫描权限，进入手动输入页面
            nibName = @"SCAddPersonSignController";
        }
    }
    return nibName;
}

/// 弹出警告的提示框（针对一些没有内容的模块的提示）
- (void)showWarningAlert:(UIViewController *)controller {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"请升级到最新版本" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) { /**/ }];
    [alert addAction:confirmAction];
    [controller presentViewController:alert animated:YES completion:nil];
}

/// 获取+号页面展示的内容
+ (NSMutableArray *)gainPlusItems {
    
    NSMutableArray *list = [NSMutableArray arrayWithCapacity:0];

    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeReportManager]) {
        /// 报修报事
        NSString *controllerName = ([SCUser currentLoggedInUser].userType == SCUserTypeCommunityAdmin) ? @"SCAddReportContentViewController" : @"SCAddGroupReportViewController";
        SCMenuItem *item = SCCreateMenuItem(SCMenuItemCodeAddReport, @"报修报事", controllerName, controllerName, YES);
        item.icon = @"report_icon";
        [list addObject:item];
    }
    
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeDeposit]) {
        /// 寄存登记
        SCMenuItem *item = SCCreateMenuItem(SCMenuItemCodeDepositSign, @"寄存登记", @"SCAddDepositController", @"SCAddDepositController", YES);
        item.icon = @"deposit_icon";
        [list addObject:item];
    }
    
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodePersonSign]) {
        /// 人行登记
        SCMenuItem *item = SCCreateMenuItem(SCMenuItemCodePersonSign, @"人行登记", @"SCPersonSignMainController", @"SCPersonSignMainController", YES);
        item.icon = @"person_sign_icon";
        [list addObject:item];
    }
    
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeCarSign]) {
        /// 车访登记
        SCMenuItem *item = SCCreateMenuItem(SCMenuItemCodeCarSign, @"车访登记", @"SCCarSignMainController", @"SCCarSignMainController", YES);
        item.icon = @"car_sign_icon";
        [list addObject:item];
    }
    
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeDecorationManager]) {
        /// 装修登记
        SCMenuItem *item = SCCreateMenuItem(SCMenuItemCodeDecorationSign, @"装修登记", @"SCRoomNumSelectViewController", @"SCRoomNumSelectViewController", YES);
        item.icon = @"decoration_sign_icon";
        [list addObject:item];
    }
    
    return list;
}

+ (SCMenuItem *)homeScanMenuItem {
    return SCCreateMenuItem(SCMenuItemCodeHomeScan, @"扫一扫", @"SCScanInputViewController", nil, YES);
}

@end
