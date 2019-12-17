//
//  SCBaseNavigationController.m
//  DreamHouseServerDL
//
//  Created by MCDuff on 16/3/31.
//  Copyright © 2016年 MCDuff. All rights reserved.
//

#import "SCBaseNavigationController.h"
#import "SCNavigationControllerProtocol.h"
#import "UIImage+UIImageExtras.h"

#define BaseNavTitleColor [UIColor whiteColor]    //基本导航标题颜色

@interface UINavigationController (UInavigationControllerNeedshouldPopItem)

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item;

@end

@interface SCBaseNavigationController ()

@end

@implementation SCBaseNavigationController

- (UIModalPresentationStyle)modalPresentationStyle {
    return UIModalPresentationFullScreen;
}

+ (void)initialize {
    // 获取特定类的所有导航条
    UINavigationBar *navigationBar = [UINavigationBar appearanceWhenContainedIn:self, nil];
    [navigationBar setBackIndicatorImage:[UIImage imageNamed:@"navbar_back"]];
    [navigationBar setBackIndicatorTransitionMaskImage:[UIImage imageNamed:@"navbar_back"]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = SC_BACKGROUD_COLOR;
    [self setupStyle];
    // Do any additional setup after loading the view.
}

/**
 *  设置导航条样式
 */
- (void)setupStyle{
    [self configNavShowStyle:NO];
    
    if ([UINavigationBar instancesRespondToSelector:@selector(setShadowImage:)]){
        [[UINavigationBar appearance] setShadowImage:[UIImage new]];
    }
    [UINavigationBar appearance].tintColor = [UIColor whiteColor];
    [UINavigationBar appearance].titleTextAttributes =
    @{NSForegroundColorAttributeName: [UIColor whiteColor],
    NSFontAttributeName: SC_TEXT_FONT_NAV_TITLE};
}


/// 配置导航条的显示（登录页面特殊）
- (void)configNavShowStyle:(BOOL)isLogin {
    
    if (isLogin) {
        //// 登录页面 蓝色
        [[UINavigationBar appearance] setBackgroundImage:[UIImage createGradientImageFromColors:@[HEXCOLOR(0x2862C7), HEXCOLOR(0x2862C7)] gradientType:SCGradientTypeTopToBottom imgSize:CGSizeMake(SCREEN_WIDTH, self.navigationBar.height + SCStatusBarHeight)] forBarMetrics:UIBarMetricsDefault];
    } else {
        /// 登录后主风格渐变
        [[UINavigationBar appearance] setBackgroundImage:[UIImage createGradientImageFromColors:@[SC_NAVBAR_BEGIN_COLOR, SC_NAVBAR_END_COLOR] gradientType:SCGradientTypeTopToBottom imgSize:CGSizeMake(SCREEN_WIDTH, self.navigationBar.height + SCStatusBarHeight)] forBarMetrics:UIBarMetricsDefault];
    }
}

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item{
    UIViewController *vc = self.topViewController;
    if (item!=vc.navigationItem) {
        return [super navigationBar:navigationBar shouldPopItem:item];
    }
    if ([vc conformsToProtocol:@protocol(SCNavigationControllerProtocol)]) {
        if ([(id<SCNavigationControllerProtocol>)vc sc_navigationControllerShouldPopWhenBackItemSelected:self]) {
            return [super navigationBar:navigationBar shouldPopItem:item];
        }else{
            return NO;
        }
    }else{
        return [super navigationBar:navigationBar shouldPopItem:item];
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    if (self.viewControllers.count > 0) {
        viewController.hidesBottomBarWhenPushed = YES;
    }
    viewController.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleDone target:nil action:nil];
    [super pushViewController:viewController animated:animated];
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.topViewController;
}

@end
