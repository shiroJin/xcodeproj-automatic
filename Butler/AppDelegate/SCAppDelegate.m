//
//  SCAppDelegate.m
//  Butler
//
//  Created by Linkou Bian on 8/22/14.
//  Copyright (c) 2014 UAMA Inc. All rights reserved.
//

#import "SCAppDelegate.h"
#import "SCAppDelegateHelper.h"
#import "SCCheckVersion.h"
#import "UncaughtExceptionHandler.h"
#import <AudioToolbox/AudioToolbox.h>
#import <SharkORM/SharkORM.h>
#import "SCNetworkConfig.h"
#import "SCUserAccountHelper.h"
#import "SCAPNsHelper.h"
#import "SCBaseDBManager.h"
#import <UMShare/UMShare.h>
#import "NSNumber+ChineseCurrency.h"
#import "SCLaunchViewController.h"

@interface SCAppDelegate () <SRKDelegate>

@property (strong, nonatomic) UIViewController *launchVc;

@end

@implementation SCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [SCAppDelegateHelper networkConfig];
    
    [self configSharkORM];
    
    ///商品金额全局默认显示是否保留两位小数
    [NSNumber setPriceDefaultNeedTwoFractions:YES];
    /// 获取登录方式
    [SCUserAccountHelper fetchLoginTypeConfig];
    /// 默认启动可以显示Launch页面
    [SCUserAccountHelper setupShowLaunch:YES];
    
    [SCAppDelegateHelper start];
    [[SCAPNsHelper sharedInstance] setUpWithLaunchOptions:launchOptions];
    [SCUserAccountHelper handleWithWindow:self.window removeAPNs:NO];
    
    // Version Check
    [[SCCheckVersion sharedInstance] checkVersion];
    [LimitInput sharedInstance];
    [SCAppDelegateHelper configKeyboardManager];
    [SCAppDelegateHelper customizeAppearance];
    [SCAppDelegateHelper beginNetworkMonitor];
    // 版本升级针对离线数据的处理
    [SCBaseDBManager compatibleAppDBDataHandel];
    //InstallUncaughtExceptionHandler();
    
    if ([SCUser currentLoggedInUser].isLogin) { // 注意，只有登录用户才显示广告页
        self.launchVc = [[SCLaunchViewController alloc] initWithNibName:[SCLaunchViewController sc_className] bundle:nil];
    }
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[SCAPNsHelper sharedInstance] resetBadge];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Required
    [[SCAPNsHelper sharedInstance] registerDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"did Fail To Register For Remote Notifications With Error: %@", error);
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [[SCAPNsHelper sharedInstance] handleRemoteNotification:userInfo
                                           applicationState:application.applicationState];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Version Check
    NSString *token = [SCUser currentLoggedInUser].token;
    if (ISNULL(token).length > 0) {
        [[SCCheckVersion sharedInstance] checkVersion];
    }
}

/// 设置系统回调
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    /// 友盟
    BOOL result = [[UMSocialManager defaultManager] handleOpenURL:url];
    if (!result) {
        // 其他如支付等SDK的回调
    }
    return result;
}


/// 虚拟管家SDK需要做的处理
- (void)applicationDidEnterBackground:(UIApplication *)application {
    
    UIApplication* app = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [app beginBackgroundTaskWithExpirationHandler: ^{
                  dispatch_async(dispatch_get_main_queue(), ^{
                                     if(bgTask != UIBackgroundTaskInvalid) {
                                         bgTask = UIBackgroundTaskInvalid;
                                     }
                                 });
              }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
                       dispatch_async(dispatch_get_main_queue(), ^{
                                          if (bgTask != UIBackgroundTaskInvalid) {
                                              bgTask = UIBackgroundTaskInvalid;
                                          }
                                      });
                   });
}

// 配置sharkORM
- (void)configSharkORM {
    [SharkORM setDelegate:self];
    [SharkORM openDatabaseNamed:@"Butler_DB"];
}

@end
