//
//  SCBaseTabBarController.m
//  Butler
//
//  Created by zhanglijiong on 2018/6/11.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCBaseTabBarController.h"
#import "UIImage+UIImageExtras.h"

#import "SCWorkBenchViewController.h"
#import "SCBaseNavigationController.h"
#import "SCLeaderViewController.h"
#import "SCContactListViewController.h"

@interface SCBaseTabBarController () <UITabBarDelegate>

@end

//背景颜色
#define kTabBarBackColor  HEXCOLOR(0xf8f8f8)
//字体大小
#define kTabBarItemFont [UIFont systemFontOfSize:12.f]
//默认字体颜色
#define kTabBarItemColor HEXCOLOR(0x7B7B80)
//选中颜色
#define kTabBarItemSelectedColor HEXCOLOR(0x4E85FE)

@implementation SCBaseTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupTabBarStyle];
    [self setUpAllChildViewController];
    // Do any additional setup after loading the view.
}

/**
 *  设置UITabBar样式
 */
- (void)setupTabBarStyle{
    [[UITabBar appearance] setBackgroundImage:[UIImage imageWithColor:kTabBarBackColor size:CGSizeMake(SCREEN_WIDTH, 49)]];
    [[UITabBar appearance] setBarTintColor:kTabBarItemColor];
    [[UITabBar appearance] setTintColor:kTabBarItemSelectedColor];
    [[UITabBar appearance] setTranslucent:NO];
}

/**
 *  添加所有子控制器
 */
- (void)setUpAllChildViewController{
    
    ///工作台
    SCWorkBenchViewController *benchVC = [[SCWorkBenchViewController alloc] initWithNibName:[SCWorkBenchViewController sc_className] bundle:nil];
    [self addChildViewController:benchVC image:[UIImage imageNamed:@"workbench_navicon"] selectedImage:[UIImage imageNamed:@"workbench_navicon_active"] title:@"工作台"];
    
    SCContactListViewController *contactsVC = [[SCContactListViewController alloc] initWithNibName:[SCContactListViewController sc_className] bundle:nil];
    [self addChildViewController:contactsVC image:[UIImage imageNamed:@"addressbook_navicon"] selectedImage:[UIImage imageNamed:@"addressbook_navicon_active"] title:@"通讯录"];
    
    ///数据
    SCLeaderViewController *dataVC = [[SCLeaderViewController alloc] initWithNibName:[SCLeaderViewController sc_className] bundle:nil];
    [self addChildViewController:dataVC image:[UIImage imageNamed:@"data_navicon"] selectedImage:[UIImage imageNamed:@"data_navicon_active"] title:@"数据"];
}

/**
 *  添加一个子控制器
 *
 *  @param viewController 控制器
 *  @param image 默认图片
 *  @param selectedImage 选中图片
 *  @param title 标题
 */
- (void)addChildViewController:(UIViewController *)viewController image:(UIImage *)image selectedImage:(UIImage *)selectedImage title:(NSString *)title{
    SCBaseNavigationController *navC = [[SCBaseNavigationController alloc]initWithRootViewController:viewController];
    navC.tabBarItem = [self itemWithTitle:title image:image selectedImage:selectedImage];
    viewController.navigationItem.title = title;
    
    [self addChildViewController:navC];
}

/**
 *  设置UITabBarItem样式
 *
 *  @param title 标题
 *  @param image 默认图片
 *  @param selectedImage 选中图片
 *
 *  @return UITabBarItem
 */
- (UITabBarItem *)itemWithTitle:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage{
    UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:[image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] selectedImage:[selectedImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    
    NSMutableDictionary *textAttrs = [NSMutableDictionary dictionary];
    textAttrs[NSForegroundColorAttributeName] = kTabBarItemColor;
    textAttrs[NSFontAttributeName] = kTabBarItemFont;
    
    NSMutableDictionary *textAttrsPrass = [NSMutableDictionary dictionary];
    textAttrsPrass[NSForegroundColorAttributeName] = kTabBarItemSelectedColor;
    
    [tabBarItem setTitleTextAttributes:textAttrs forState:UIControlStateNormal];
    [tabBarItem setTitleTextAttributes:textAttrsPrass forState:UIControlStateSelected];
    
    return tabBarItem;
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    NSLog(@"======%@",item.title);
    [SCTrackManager trackEvent:kWorkbenchBottomTabClick attributes:@{@"tabName":item.title}];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
