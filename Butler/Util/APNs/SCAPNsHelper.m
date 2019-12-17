//
//  SCAPNsHelper.m
//  Butler
//
//  Created by abeihaha on 16/9/14.
//  Copyright © 2016年 UAMA Inc. All rights reserved.
//

#import "SCAPNsHelper.h"
#import "SCAppDelegate.h"
#import "SCOrderBrief.h"
#ifdef NSFoundationVersionNumber_iOS_9_x_Max
#import <UserNotifications/UserNotifications.h>
#endif
#import "SCServiceOrderDetailsController.h"
#import "SCNotificationDetailViewController.h"
#import "SCWebViewController.h"

#import "SCResetNoticeCountAPI.h"
#import "SCNotificationManager.h"

#import "SCElectronicPatrolController.h"
#import "SCCurrentViewController.h"
#import "SCPropertyOnlinePayCodeController.h"
#import "SCPropertyOfflinePaymentController.h"
#import "SCPropertyPaymentOrderDetailViewController.h"
#import "SCPlaceBookDetailController.h"
/// 侧滑，nav的push需要特殊处理
#import "SCSettingsViewController.h"
#import <MJExtension/MJExtension.h>
#import <UIViewController+CWLateralSlide.h>
#import "SCBaseWebViewController.h"
#import "SCNotificationModel.h"

@interface SCAPNsHelper () <JPUSHRegisterDelegate>

@end

@implementation SCAPNsHelper

static SCAPNsHelper *instance = nil;

#pragma mark - Singleton Method

+ (instancetype)sharedInstance {
    return [[self alloc] init];
}

- (instancetype)init {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super init];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

#pragma mark - 设置极光推送相关信息

- (void)setUpWithLaunchOptions:(NSDictionary *)launchOptions {
    /// 注册极光推送
    [self registerJPUSH];
    /// 设置极光推送配置信息
    [self setupJPUSHWithLaunchOptions:launchOptions];
    
    /// 这里的处理，是为了程序启动，就清除角标
    NSDictionary *remoteNotification = [launchOptions objectForKey: UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotification) {
        SCAppDelegate *appDelegate = (SCAppDelegate *)[[UIApplication sharedApplication] delegate];
        appDelegate.isLaunchedByNotification = YES;
        appDelegate.remoteNotification = remoteNotification;
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        [JPUSHService resetBadge];
//        [self resetBadgeCountToServer];
    }
}

/// 注册极光推送
- (void)registerJPUSH {
    
    // 3.0.0及以后版本注册可以这样写，也可以继续用旧的注册方式，目前使用新的
    JPUSHRegisterEntity * entity = [[JPUSHRegisterEntity alloc] init];
    entity.types = JPAuthorizationOptionAlert|JPAuthorizationOptionBadge|JPAuthorizationOptionSound;
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {
        //可以添加自定义categories
        //    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
        //      NSSet<UNNotificationCategory *> *categories;
        //      entity.categories = categories;
        //    }
        //    else {
        //      NSSet<UIUserNotificationCategory *> *categories;
        //      entity.categories = categories;
        //    }
    }
    [JPUSHService registerForRemoteNotificationConfig:entity delegate:self];
}

/// 设置极光推送相关信息
- (void)setupJPUSHWithLaunchOptions:(NSDictionary *)launchOptions {
    
    /// 配置了开发环境的推送（之前的都是生产环境，没有配置开发环境）
    /** 目前极光开发和生产是两个账号，避免后台配置错误，都置为YES 6/13/2019 */
#ifdef DEBUG
    /// isProduction 是否生产环境. 如果为开发状态,设置为 NO; 如果为生产状态,应改为 YES.
    BOOL isProduction = YES;
#elif RELEASE
    BOOL isProduction = YES;
#else
    BOOL isProduction = YES;
#endif
    
    //如不需要使用IDFA，advertisingIdentifier 可为nil
    [JPUSHService setupWithOption:launchOptions
                           appKey:kJPushAppKeyString
                          channel:kJPushChannelID
                 apsForProduction:isProduction
            advertisingIdentifier:nil];
    
    //2.1.9版本新增获取registration id block接口。
    [JPUSHService registrationIDCompletionHandler:^(int resCode, NSString *registrationID) {
        if(resCode == 0){
            NSLog(@"registrationID获取成功：%@",registrationID);
        }
        else{
            NSLog(@"registrationID获取失败，code：%d",resCode);
        }
    }];
    
}

/// 设置设备的deviceToken
- (void)registerDeviceToken:(NSData *)deviceToken {
    NSLog(@"------设备token = %@------",deviceToken);
    [JPUSHService registerDeviceToken:deviceToken];
}

/// 设置推送别名(3.0.6版本新方法)
- (void)registerJPushUsingUserAlias:(NSString *)userAlias {
    
    /// 设置推送别名方法的替换，之前的设置方式，在3.0.6版本已经废弃，下面的方法，是最新的方法
    if (ISNULL(userAlias).length > 0) {
        /// 注册极光推送
        [self registerJPUSH];
        
        /// 设置推送别名
        [JPUSHService setAlias:userAlias completion:^(NSInteger iResCode, NSString *iAlias, NSInteger seq) {
            NSLog(@"设置别名iAlias的回调 iResCode:%ld iAlias:%@ seq:%ld", iResCode, iAlias, seq);
        } seq:1];
        
    } else {
        /// 删除推送别名
        [JPUSHService deleteAlias:^(NSInteger iResCode, NSString *iAlias, NSInteger seq) {
            NSLog(@"删除别名iAlias的回调 iResCode:%ld iAlias:%@ seq:%ld", iResCode, iAlias, seq);
        } seq:2];
    }
}


#pragma  收到通知的处理

/// 收到通知的处理
- (void)handleRemoteNotification:(NSDictionary *)userInfo
                applicationState:(UIApplicationState)applicationState {
    NSLog(@"------通知内容 = %@------",userInfo);
    [JPUSHService handleRemoteNotification:userInfo];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

    //程序当前正处于前台
    if (applicationState == UIApplicationStateActive) {
        NSLog(@"------UIApplicationStateActive接收到推送------");
        [self showToastWithUserInfo:userInfo];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        [JPUSHService resetBadge];
//        [self resetBadgeCountToServer];
        
    } else if (applicationState == UIApplicationStateInactive) {
        //程序当前正处于待激活（a.下接状态栏，看通知 b.双击home键，下面弹出任务运行栏 c.锁屏。应该程序也非后台状态。）
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        [JPUSHService resetBadge];
//        [self resetBadgeCountToServer];
        NSLog(@"------UIApplicationStateInactive接收到推送------");
        [self actionForPushVCWithData:userInfo];
        
    } else if (applicationState == UIApplicationStateBackground) {
        //程序当前正处于后台（a.按home键 b.启动其它应用，把当前应用挤入后台。）
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        [JPUSHService resetBadge];
//        [self resetBadgeCountToServer];
        NSLog(@"------UIApplicationStateBackground接收到推送------");
        [self actionForPushVCWithData:userInfo];
    }
}


- (void)resetBadge {
    [JPUSHService resetBadge];
//    [self resetBadgeCountToServer];
}

#pragma mark- JPUSHRegisterDelegate

#ifdef NSFoundationVersionNumber_iOS_9_x_Max

/// 前台得到的通知处理
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(NSInteger options))completionHandler {
    NSDictionary * userInfo = notification.request.content.userInfo;
    
    UNNotificationRequest *request = notification.request; // 收到推送的请求
    UNNotificationContent *content = request.content; // 收到推送的消息内容
    
    NSNumber *badge = content.badge;  // 推送消息的角标
    NSString *body = content.body;    // 推送消息体
    UNNotificationSound *sound = content.sound;  // 推送消息的声音
    NSString *subtitle = content.subtitle;  // 推送消息的副标题
    NSString *title = content.title;  // 推送消息的标题
    
    if ([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [JPUSHService handleRemoteNotification:userInfo];
        NSLog(@"iOS10 前台收到远程通知:%@", userInfo);
        //[rootViewController addNotificationCount];
        
    } else {
        // 判断为本地通知
        NSLog(@"iOS10 前台收到本地通知:{\nbody:%@，\ntitle:%@,\nsubtitle:%@,\nbadge：%@，\nsound：%@，\nuserInfo：%@\n}",body,title,subtitle,badge,sound,userInfo);
    }
    
    // 需要执行这个方法，选择是否提醒用户，有Badge、Sound、Alert三种类型可以设置
    completionHandler(UNNotificationPresentationOptionBadge|UNNotificationPresentationOptionSound|UNNotificationPresentationOptionAlert);
    
    /// 显示黑色自定义通知条条
    //NSString *message = [NSString stringWithFormat:@"%@",[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]];
    [self showToastWithUserInfo:userInfo];
}


/// 通知响应对象
- (void)jpushNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler {
    
    NSDictionary * userInfo = response.notification.request.content.userInfo;
    UNNotificationRequest *request = response.notification.request; // 收到推送的请求
    UNNotificationContent *content = request.content; // 收到推送的消息内容
    
    NSNumber *badge = content.badge;  // 推送消息的角标
    NSString *body = content.body;    // 推送消息体
    UNNotificationSound *sound = content.sound;  // 推送消息的声音
    NSString *subtitle = content.subtitle;  // 推送消息的副标题
    NSString *title = content.title;  // 推送消息的标题
    
    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [JPUSHService handleRemoteNotification:userInfo];
        NSLog(@"iOS10 收到远程通知:%@", userInfo);
        
    } else {
        // 判断为本地通知
        NSLog(@"iOS10 收到本地通知:{\nbody:%@，\ntitle:%@,\nsubtitle:%@,\nbadge：%@，\nsound：%@，\nuserInfo：%@\n}",body,title,subtitle,badge,sound,userInfo);
    }
    
    // 系统要求执行这个方法
    completionHandler();
    
    [self actionForPushVCWithData:userInfo];
}
#endif

#pragma mark - Private Methods

/// 重置未读消息数
- (void)resetBadgeCountToServer {
    
    NSString *token = [SCUser currentLoggedInUser].token;
    if (ISNULL(token).length > 0) {
        /// 登录了才进行请求
        SCResetNoticeCountAPI *resetNoticeCountAPI = [[SCResetNoticeCountAPI alloc] init];
        [resetNoticeCountAPI startWithCompletionWithSuccess:^(id responseDataDict) {
            NSLog(@"重置未读消息数成功");
        } failure:^(NSError *error) {
            NSLog(@"重置未读消息数出错==%@==",error.localizedDescription);
        }]; 
    }
}

/// 自定义收到通知的Toast
- (void)showToastWithUserInfo:(NSDictionary *)userInfo {
    
    NSLog(@"------推送过来了，需要显示------");
    /// 防止crash
    if (![userInfo isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    /// 取得 APNs 标准信息内容
    NSDictionary *apsDic = [userInfo objectForKey:@"aps"];
    /// 显示的message
    NSString *message;
    if ([apsDic isKindOfClass:[NSDictionary class]]) {
        /// 防止crash
        message = [NSString stringWithFormat:@"%@",[apsDic objectForKey:@"alert"]];
    }
    
    /// 后台推送类型区分
    SCPushModuleType type = [[userInfo objectForKey:@"type"] integerValue];
    
    /// 获取当前的最顶部VC
    UIViewController *currentVC = [SCCurrentViewController presentViewController];
    
    /// 这种处理，是让通知显示的Toast在电子巡更页面显示
    if (type == SCPushModuleTypeElectronicPatrol) {
        /// 产品要求，电子巡更模块，只有在电子巡更主页才显示自定义的Toast
        if ([currentVC isKindOfClass:[SCElectronicPatrolController class]]) {
            /// 只有在电子巡更主页显示
            [self showToastWithMessage:message controller:currentVC];
        }
    }
    else if (type == SCPushModuleTypeOnlinePay) {
        /// 生活缴费，支付成功的结果处理
        [self showToastWithMessage:message controller:currentVC];
        if ([currentVC isKindOfClass:[SCPropertyOnlinePayCodeController class]]) {
            /// 线上支付
            SCPropertyOnlinePayCodeController *payCodeVC = (SCPropertyOnlinePayCodeController *)currentVC;
            /// 后台推送类型区分
            SCPaymentResultType payType = [userInfo[@"payStatus"] integerValue];
            NSString *serialNumber = userInfo[@"serialNumber"];
            [payCodeVC dealWithPaymentResult:payType serialNumber:serialNumber];
        } else if ([currentVC isKindOfClass:[SCPropertyOfflinePaymentController class]]) {
            /// 线下支付，也需要销账
            SCPropertyOfflinePaymentController *payCodeVC = (SCPropertyOfflinePaymentController *)currentVC;
            /// 后台推送类型区分
            SCPaymentResultType payType = [userInfo[@"payStatus"] integerValue];
            NSString *serialNumber = userInfo[@"serialNumber"];
            [payCodeVC dealWithPaymentResult:payType serialNumber:serialNumber];
        }
    }
    else {
        /// 其余通用的处理
        [self showToastWithMessage:message controller:currentVC];
    }
}

- (void)showToastWithMessage:(NSString *)message controller:(UIViewController *)controller {
    NSDictionary *topBarConfig = @{kDXTopBarBackgroundColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8], kDXTopBarTextColor : [UIColor whiteColor],kDXTopBarTextFont : [UIFont systemFontOfSize:12.0f]};
    // 这里要判断是否是UIAlertController，UIAlertController也是UIViewController的一种，所以需要特殊处理，解决推送消息会显示在UIViewController上面的bug（5948）
    if (![controller isKindOfClass:[UIAlertController class]] && ([controller isKindOfClass:[UITableViewController class]] || [controller isKindOfClass:[UIViewController class]])) {
        [controller showTopMessage:message topBarConfig:topBarConfig dismissDelay:3.0 withTapBlock:^{}];
    }
}

- (void)tagsAliasCallback:(int)iResCode
                     tags:(NSSet *)tags
                    alias:(NSString *)alias {
    if (iResCode == 0) {
        NSLog(@"------别名绑定成功 In 启动------");
    } else {
        NSLog(@"------别名绑定失败 In 启动------");
    }
}

/// 点击推送，会跳转到具体页面
- (void)actionForPushVCWithData:(NSDictionary *)userInfo {
    
    if (![userInfo isKindOfClass:[NSDictionary class]]) {
        /// 不是dic，不继续执行
        return;
    }
    
    /// 后台推送类型区分
    SCPushModuleType type = [[userInfo objectForKey:@"type"] integerValue];
    if (type == SCPushModuleTypeCommon) {
        /// 以前没有做区分，服务工单/订单用的是这个值
        NSString *caseId = userInfo[@"caseId"];
        SCOrderType orderType = [userInfo[@"orderType"] integerValue];
        SCServiceOrderDetailsController *orderVC = [[SCServiceOrderDetailsController alloc] initWithNibName:[SCServiceOrderDetailsController sc_className] bundle:nil];
        SCOrderBrief *order = [[SCOrderBrief alloc] init];
        order.caseId = caseId;
        orderVC.order = order;
        if (orderType == SCOrderTypeBusiness) {
            orderVC.entranceType = SCOrderEntranceTypeBusinessOrder;
        } else {
            orderVC.entranceType = SCOrderEntranceTypeNotMine;
        }
        [self pushViewController:orderVC animated:YES];
        
    } else if (type == SCPushModuleTypePropertyPayment) {
        /// 收到生活缴费的推送，要跳转到订单详情
        NSString *orderId = userInfo[@"orderId"];
        if (orderId.length > 0) {
            SCPropertyPaymentOrderDetailViewController *orderVC = [[SCPropertyPaymentOrderDetailViewController alloc] initWithNibName:[SCPropertyPaymentOrderDetailViewController sc_className] bundle:nil];
            orderVC.orderId = orderId;
            [self pushViewController:orderVC animated:YES];
        }
    } else if (type == SCPushModuleTypeNotification) {
        /// 通知推送
        SCNotificationModel *notiModel = [SCNotificationModel mj_objectWithKeyValues:userInfo];
        // 详情页
        SCBaseWebViewController *vc = [[SCBaseWebViewController alloc] init];
        vc.urlString =  notiModel.loadUrlString;
        [self pushViewController:vc animated:YES];

        // 标记通知已读
        [SCNotificationManager dealNoticeReaded:notiModel.noticeId scopeType:notiModel.noticeScope success:^(id responseDataDict) {
            NSLog(@"设置消息未读成功！");
        } failure:^(NSError *error) {
            NSLog(@"设置消息未读失败：%@", error);
        }];
    } else if (type == SCPushModuleTypeReservationPlace) {
        //跳转场地预订详情页面
        NSString *orderId = userInfo[@"orderId"];
        SCPlaceBookDetailController *placeBookDetailVC = [[SCPlaceBookDetailController alloc] initWithNibName:[SCPlaceBookDetailController sc_className] bundle:nil];
        placeBookDetailVC.orderId = orderId;
        [self pushViewController:placeBookDetailVC animated:YES];
    }
    else if (type == SCPushModuleTypeH5PropertyPayment) { // 项目缴费页面
        NSString *orderId = userInfo[@"orderId"];
        SCBaseWebViewController *webVC = [[SCBaseWebViewController alloc] init];
        webVC.urlString = [NSString stringWithFormat:@"%@%@?fromPush=1&orderId=%@", kDistributioneBaseCommonUrl, kCommunityPaymentH5OrderDetailUrlString, orderId];
        webVC.needJointParams = YES;
        [self pushViewController:webVC animated:YES];
    }
}


/// 侧滑菜单出来的跳转处理
- (void)pushViewController:(UIViewController *)vc animated:(BOOL)animated {
    if (!vc) {
        return;
    }
    /// 获取当前的最顶部VC
    UIViewController *currentVC = [SCCurrentViewController presentViewController];
    if ([currentVC isKindOfClass:[SCSettingsViewController class]]) {
        /// 对于抽屉侧滑出来的设置页面，要特殊处理
        [currentVC cw_pushViewController:vc drewerHiddenDuration:0.01];
    } else {
        [currentVC.navigationController pushViewController:vc animated:YES];
    }
}

@end
