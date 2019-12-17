//
//  SCSettingsViewController.m
//  Butler
//
//  Created by abeihaha on 16/8/9.
//  Copyright © 2016年 UAMA Inc. All rights reserved.
//  APP设置界面（左侧侧滑VC）

#import "SCSettingsViewController.h"

/// vc
#import "SCWebViewController.h"
#import "SCToUploadViewController.h"
#import "SCEditAdviceViewController.h"
#import "SCUserInfoController.h"
#import "SCNotificationListViewController.h"
#import "MAMyInvitationCodeController.h"
#import "SCRemindSettingContainerController.h"
#import "SCMineQRCodeController.h"
#import "SCAccountSwitchViewController.h"
/// view
#import "SCSettingHeadCell.h"
#import "SCSettingCommonCell.h"
/// model
#import "SCSettingModel.h"
/// api
#import "SCFetchUnreadCountAPI.h"
#import "SCFetchTodayTaskCountAPI.h"
/// other
#import "SCVersionHelper.h"
#import "SCWorkBanchManager.h"
#import "SCCheckVersion.h"
#import "SCCacheClient.h"
#import "SCAPNsHelper.h"
#import "SCUserAccountHelper.h"
#import<SystemConfiguration/CaptiveNetwork.h>
#import<SystemConfiguration/SystemConfiguration.h>
#import<CoreFoundation/CoreFoundation.h>
#import <UIViewController+CWLateralSlide.h>
#import "SCSettingConfig.h"
#import "SCAppDelegateHelper.h"
#import "SCLocalStorageAccountsService.h"

@interface SCSettingsViewController ()<UITableViewDataSource, UITableViewDelegate >

@property (weak, nonatomic) IBOutlet UITableView *tableView;

// 显示的数据
@property (nonatomic, strong) NSMutableArray *listArray;
/// 未读通知数
@property (nonatomic, assign) NSInteger  unreadCount;
/// 已经完成任务数
@property (nonatomic, assign) NSInteger finishCount;
/// 用户类型
@property (assign, nonatomic) SCUserType userType;


@end

@implementation SCSettingsViewController

#pragma mark - 生命周期方法
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNav];
    [self setupData];
    [self setupView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidLayoutSubviews {
    self.view.width = SCLeftDrawerWidth();
}


#pragma mark - 固定方法
- (void)setupNav {
    
}

- (void)setupView {
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    [self.tableView registerNib:[UINib nibWithNibName:[SCSettingHeadCell sc_className] bundle:nil] forCellReuseIdentifier:[SCSettingHeadCell sc_className]];
    [self.tableView registerNib:[UINib nibWithNibName:[SCSettingCommonCell sc_className] bundle:nil] forCellReuseIdentifier:[SCSettingCommonCell sc_className]];
}

- (void)setupData {
    /// 获取未读通知数
    [self requestForGianUnreadCount];
    /// 获取今日已完成任务数
    [self requestForGianTodayTaskCount];
}

#pragma mark - Public Method

- (void)setUpWithUserType:(SCUserType)userType {
    _userType = userType;
}

/// 返回侧滑VC的宽
CGFloat SCLeftDrawerWidth(void) {
    /// 可根据屏幕宽度返回不同宽度
    return SCREEN_WIDTH * (18.0/25.0);
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // 最顶部，是一个大cell
    return self.listArray.count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.row == 0) {
        /// 第一个头像的cell
        return 175.f;
    }
    
    SCSettingModel *model = self.listArray[indexPath.row - 1];
    if ([model.name isEqualToString:SCSettingChangeDevURL]) {
#ifdef DISTRIBUTION
        return CGFLOAT_MIN;
#else
        return 40.0f;
#endif
    }
    else if ([model.name isEqualToString:SCSettingWiFiItem]) {
        if (![SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeWIFI]) {
            /// WiFi没权限，就不显示
            return CGFLOAT_MIN;
        }
    }
    else if ([model.name isEqualToString:SCSettingMyInviteCodeItem]) {
        if (![SCGlobalDataManager sharedInstance].isInvite) {
            /// 没邀请码模块，就不显示
            return CGFLOAT_MIN;
        }
    }
    
    return 40.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell ;
    
    if (indexPath.row == 0) {
        SCSettingHeadCell *headCell = [tableView dequeueReusableCellWithIdentifier:[SCSettingHeadCell sc_className] forIndexPath:indexPath];
        [headCell refreshCellWithFinishCount:self.finishCount];
        cell = headCell;
    } else {
        SCSettingCommonCell *commonCell = [tableView dequeueReusableCellWithIdentifier:[SCSettingCommonCell sc_className] forIndexPath:indexPath];
        [self configTableViewCell:commonCell atIndexPath:indexPath];
        cell = commonCell;
    }
    return cell;
}

#pragma mark - UITableViewDelegate Method

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 0) {
        /// 进入账号资料页面
        [self pushUserInfoVC];
    } else {
        SCSettingModel *model = self.listArray[indexPath.row - 1];
        SEL method = NSSelectorFromString(model.action);
        //点击执行方法
        //        ((void (*)(id, SEL))[self methodForSelector:action])(self, method);
        if ([self respondsToSelector:method]) {
            SuppressPerformSelectorLeakWarning(
                                               [self performSelector:method];
                                               );
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {

    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    /// 这样，小屏幕就不会贴底部太近
    return 44.f;
}

#pragma mark - Config TableViewCell Method

- (void)configTableViewCell:(SCSettingCommonCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    SCSettingModel *model = self.listArray[indexPath.row - 1];
    
    NSString *title = model.name;
    NSString *content = @"";
    BOOL showUnread = NO;
    
    if ([title isEqualToString:SCSettingNotifiItem]) {
        /// 新通知
        if (self.unreadCount > 0) {
            content = [@(self.unreadCount) stringValue];
            if (self.unreadCount > 99) {
                content = @"99+";
            }
        }
        showUnread = YES;
    }
    else if ([title isEqualToString:SCSettingWaitUploadItem]) {
        /// 待上传任务
        NSInteger uloadCount = [SCWorkBanchManager fetchTotalUploadCount];
        if (uloadCount > 0) {
            content = [@(uloadCount) stringValue];
            if (uloadCount > 99) {
                content = @"99+";
            }
        }
        showUnread = YES;
    }
    else if ([title isEqualToString:SCSettingClearCacheItem]) {
        /// 清除缓存
        content = [NSString stringWithFormat:@"%.2fM",[SCCacheClient gainAllCache]];
    }
    else if ([title isEqualToString:SCSettingCheckVersionItem]) {
        /// 检查更新
        content = [NSString stringWithFormat:@"当前版本 %@",AppVersion];
    }
    
    [cell refreshCellWithTitle:title content:content showUnread:showUnread];
}

#pragma mark -  User Action Methods

/// 获取未读通知数
- (void)requestForGianUnreadCount {
    @weakify(self)
    [SCWorkBanchManager fetchUnReadNoticeNumComplete:^{
        @strongify(self)
        self.unreadCount = [SCGlobalDataManager sharedInstance].unReadNoticeCount;
        [self.tableView reloadData];
    }];
}

/// 获取今日已完成任务数
- (void)requestForGianTodayTaskCount {
    
    SCFetchTodayTaskCountAPI *todayTaskCountAPI = [[SCFetchTodayTaskCountAPI alloc] init];
    @weakify(self)
    [todayTaskCountAPI startWithCompletionWithSuccess:^(id responseDataDict) {
        @strongify(self)
        if ([responseDataDict isKindOfClass:[NSDictionary class]]) {
            self.finishCount = [responseDataDict[@"finishCount"] integerValue];
            [self.tableView reloadData];
        }
    } failure:^(NSError *error) {
        NSLog(@"获取今日已完成任务数出错==%@==",error);
    }];
}

/// 跳转账户资料页面
- (void)pushUserInfoVC {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuAvatarClick];
    SCUserInfoController *vc = [[SCUserInfoController alloc] initWithNibName:[SCUserInfoController sc_className] bundle:nil];
    [self pushViewController:vc animated:YES];
}

/// 提醒设置模块
- (void)pushToRemindSettingVC {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuReminderSettingClick];
    SCRemindSettingContainerController *vc = [[SCRemindSettingContainerController alloc] initWithNibName:[SCRemindSettingContainerController sc_className] bundle:nil];
    [self pushViewController:vc animated:YES];
}

/// 跳转通知页面
- (void)pushToNotifiVC {
    // 添加统计
    [SCTrackManager trackEvent:kWorkbenchMenuNoticeClick attributes:@{@"noticeCount":@(self.unreadCount)}];
    SCNotificationListViewController *notification = [[SCNotificationListViewController alloc] initWithNibName:[SCNotificationListViewController sc_className] bundle:nil];
    [self pushViewController:notification animated:YES];
}

// 园区WIFI事件
- (void)wifiAction {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuParkWifiClick];
    NSString *urlString = [NSString stringWithFormat:@"%@%@", kConfigBaseUrl(SCURLTypeWeb), kParkWIFIUrlString];
    SCWebViewController *controller = [[SCWebViewController alloc] initWithURL:[NSURL URLWithString:urlString]];
    [self pushViewController:controller animated:YES];
    /*NSString * urlString = @"App-Prefs:root=WIFI";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]]) {
        if ([[UIDevice currentDevice].systemVersion doubleValue] >= 10.0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
        }
    }*/
}

// 检查版本事件
- (void)checkVersionAction {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuCheckVersioneClick];
    [[SCCheckVersion sharedInstance] checkVersionHandle];
}

// 清除缓存事件
- (void)clearAllCacheData {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuClearCacheClick];
    [SCCacheClient clearAllCacheFiles:^{
        [self.tableView reloadData];
    }];
}

// 意见反馈事件
- (void)pushToFeedbackVC {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuFeedbackClick];
    SCEditAdviceViewController *vc = [[SCEditAdviceViewController alloc] initWithNibName:[SCEditAdviceViewController sc_className] bundle:nil];
    [self pushViewController:vc animated:YES];
}

/**
 切换账号
 */
- (void)pushToSwitchAccountVC {
    if ([SCLocalStorageAccountsService hasCombinedRelationShip]) {
        [self goToAccountSwitchPage];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加账号后，可在本设备快速切换，账号信息只保存在设备本地" message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAlertAction = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self goToAccountSwitchPage];
        }];
        [alert addAction:cancelAlertAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)goToAccountSwitchPage {
    SCAccountSwitchViewController *vc = [[SCAccountSwitchViewController alloc] initWithNibName:[SCAccountSwitchViewController sc_className] bundle:nil];
    [self pushViewController:vc animated:YES];
}

// 待上传事件
- (void)pushToUploadVC {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuUploadClick attributes:@{@"touploadCount":@([SCWorkBanchManager fetchTotalUploadCount])}];
    SCToUploadViewController *vc = [[SCToUploadViewController alloc] init];
    [self pushViewController:vc animated:YES];
}

// 跳转到关于界面
- (void)pushToAboutVC {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuAboutClick];
    NSString *regionId = @"", *defCommunityId = @"";
    if ([SCUser currentLoggedInUser].userType == SCUserTypeCompanyAdmin) {
        regionId = [SCUser currentLoggedInUser].orgId;
    } else if ([SCUser currentLoggedInUser].userType == SCUserTypeCommunityAdmin) {
        defCommunityId = [SCUser currentLoggedInUser].communityId;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@?token=%@&companyCode=%@&version=%@&mobileType=%@&defCommunityId=%@&regionId=%@",kConfigBaseUrl(SCURLTypeWeb),kAboutUrlString,[[SCUser currentLoggedInUser] token],kCompanyCode,AppVersion,kMobiletype,defCommunityId, regionId];
    SCWebViewController *controller = [[SCWebViewController alloc] initWithURL:[NSURL URLWithString:urlString]];
    controller.scTitle = @"关于";
    [self pushViewController:controller animated:YES];
}

/// 跳转到我的邀请人员页面
- (void)pushMyInvitePersonVC {
    MAMyInvitationCodeController *vc = [[MAMyInvitationCodeController alloc] initWithNibName:[MAMyInvitationCodeController sc_className] bundle:nil];
    [self pushViewController:vc animated:YES];
}

/// 跳转到我的二维码页面
- (void)pushToMyCodeVC {
    SCMineQRCodeController *qrcodeVC = [[SCMineQRCodeController alloc] initWithNibName:[SCMineQRCodeController sc_className] bundle:nil];
    [self pushViewController:qrcodeVC animated:YES];
}

/// 退出登录前的提示
- (void)alertForLogout {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:@"确定退出当前账号？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    // 取消
    UIAlertAction  *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * _Nonnull action) { }];
    
    @weakify(self);
    UIAlertAction  *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          @strongify(self);
                                                          [self logoutAction];
                                                      }];
    [alert addAction:cancelAction];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 退出登录
- (void)logoutAction {
    // 统计事件
    [SCTrackManager trackEvent:kWorkbenchMenuLogoutClick];
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    [[SCUser currentLoggedInUser] cleanUserInfo];
    [[SCGlobalDataManager sharedInstance] setupAllFunctionAuth];
    [[SCAPNsHelper sharedInstance] registerJPushUsingUserAlias:@""];
    [SCUserAccountHelper handleWithWindow:[[[UIApplication sharedApplication] delegate] window] removeAPNs:YES];
}

/// 侧滑菜单出来的跳转处理
- (void)pushViewController:(UIViewController *)vc animated:(BOOL)animated {
    
    if (vc) {
        if (self.drawerShow) {
            /// 抽屉内push
            [self cw_pushViewController:vc drewerHiddenDuration:0.25];
        } else {
            [self.navigationController pushViewController:vc animated:animated];
        }
    }
}


#pragma mark - lazy Method
- (NSMutableArray *)listArray {
    /// icon暂时没有使用
    if (!_listArray) {
        _listArray = [NSMutableArray new];
        [_listArray addObjectsFromArray:@[
                              [SCSettingModel itemWithName:SCSettingNotifiItem icon:@"feedback"
                                                    action:NSStringFromSelector(@selector(pushToNotifiVC))],
                              [SCSettingModel itemWithName:SCSettingWaitUploadItem icon:@"upload"
                                                    action:NSStringFromSelector(@selector(pushToUploadVC))],
                              [SCSettingModel itemWithName:SCSettingRemindSettingItem icon:@"feedback"
                                                    action:NSStringFromSelector(@selector(pushToRemindSettingVC))],
//                              [SCSettingModel itemWithName:SCSettingMyCodeItem icon:@"feedback"
//                                                    action:NSStringFromSelector(@selector(pushToMyCodeVC))],
                              [SCSettingModel itemWithName:SCSettingWiFiItem icon:@"setting_wifi"
                                                    action:NSStringFromSelector(@selector(wifiAction))],
                              [SCSettingModel itemWithName:SCSettingMyInviteCodeItem icon:@"feedback"
                                                    action:NSStringFromSelector(@selector(pushMyInvitePersonVC))],
                              [SCSettingModel itemWithName:SCSettingClearCacheItem icon:@"clear_cache"
                                                    action:NSStringFromSelector(@selector(clearAllCacheData))],
#ifndef STORE
                              [SCSettingModel itemWithName:SCSettingCheckVersionItem icon:@"update"
                                                    action:NSStringFromSelector(@selector(checkVersionAction))],
#endif
                              [SCSettingModel itemWithName:SCSettingAboutUsItem icon:@"about"
                                                    action:NSStringFromSelector(@selector(pushToAboutVC))],
                              [SCSettingModel itemWithName:SCSettingFeedbackItem icon:@"feedback"
                                                    action:NSStringFromSelector(@selector(pushToFeedbackVC))],
                              [SCSettingModel itemWithName:SCSettingSwitchAccountItem icon:@""
                                                    action:NSStringFromSelector(@selector(pushToSwitchAccountVC))],
                              [SCSettingModel itemWithName:SCSettingLogoutItem icon:@"upload"
                                                    action:NSStringFromSelector(@selector(alertForLogout))]
                                          ]];
    }
    
    return _listArray;
}


@end
