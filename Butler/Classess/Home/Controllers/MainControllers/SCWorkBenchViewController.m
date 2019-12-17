//
//  SCWorkBenchViewController.m
//  Butler
//
//  Created by zhanglijiong on 2018/6/11.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCWorkBenchViewController.h"

#import "SCWorkBenchTopView.h"
#import "SCWorkBenchFunctionTableCell.h"
#import "SCWorkBenchAddView.h"
#import "SCWorkBenchJobTableCell.h"
#import "SCWorkBenchTableHeaderView.h"
#import "SCWorkBenchEmptyView.h"
#import "SCWorkBenchGuideView.h"

#import "SCMenuItem.h"
#import "SCMineAllAppsListModel.h"
#import "SCWorkBenchTaskModel.h"

#import "CalendarHelper.h"
#import "SCWorkBanchManager.h"
#import "SCMenuItemManager.h"
#import "SCCheckVersion.h"
#import "SCDecorationStageAPI.h"
#import "SCReportDataManager.h"
#import "SCUserAccountHelper.h"
#import "SCPatrolManager.h"
#import "SCAppDelegateHelper.h"

#import "SCScanInputViewController.h"
#import "SCBaseNavigationController.h"
#import "SCSettingsViewController.h"
#import "SCWorkBenchSearchViewController.h"
#import "SCAllAppsController.h"
#import "SCSwitchAddressViewController.h"
#import "SCSelectProjectController.h"

#import "SCFetchWorkBenchDataAPI.h"
#import "SCFetchPlusServiceAPI.h"

#import <CWLateralSlide/UIViewController+CWLateralSlide.h>


@interface SCWorkBenchViewController () <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate>

/// 顶部导航栏的view
@property (strong, nonatomic) SCWorkBenchTopView *topView;
/// 暂无待办页
@property (strong, nonatomic) SCWorkBenchEmptyView *emptyView;
/// 滚动视图
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/// 添加操作按钮
@property (weak, nonatomic) IBOutlet UIButton *addWorkButton;
/// 模块数据
@property (strong, nonatomic) SCMineAllAppsListModel *allAppsListModel;
// 最后的请求时间
@property (strong, nonatomic) NSDate *lastFetchedOnDate;
/// 待办数据
@property (strong, nonatomic) NSMutableArray<SCWorkBenchTaskModel *> *benchToDoArray;
/// 计划数据
@property (strong, nonatomic) NSMutableArray<SCWorkBenchTaskModel *> *benchPlanArray;

/// 点击+号弹出的View
@property (nonatomic, strong) SCWorkBenchAddView  *plusView;

/// 左侧侧滑菜单展示，页面将要消失时，导航条显示与否，不处理
@property (nonatomic, assign) BOOL  drawerShow;

@end

@implementation SCWorkBenchViewController

- (SCWorkBenchEmptyView *)emptyView {
    if (!_emptyView) {
        _emptyView = [SCWorkBenchEmptyView loadWorkBenchEmptyView];
    }
    return _emptyView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupNav];
    [self setupView];
    [self setupData];
    
    /* 功能引导图 */
    if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"bench_guide"] boolValue]) {
        [SCWorkBenchGuideView showGuideViewWithCompletion:^{
            [[NSUserDefaults standardUserDefaults] setValue:@(YES) forKey:@"bench_guide"];
        }];
    }
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    // 为了本地缓存的默认园区不影响首页接口，每次回到首页的时候，都重新配置下网络参数
    [[SCUser currentLoggedInUser] configSwitchType];
    if (!self.lastFetchedOnDate ||
        [NSDateHelper numberOfMinsElapsedFromDate:self.lastFetchedOnDate] > kPassportsRefreshThreshold) {
        [self.tableView.mj_header beginRefreshing];
    } else {
        [self fetchUnReadNoticeNumber];
    }
    
    /// 点击通知的时候，plusView需要消失掉
    [self.plusView dismiss];

}

/// 需要在页面将要消失函数里进行navBar的显示处理
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.drawerShow) {
        [self.navigationController setNavigationBarHidden:NO animated:animated];
    }
    self.drawerShow = NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupNav {
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    _topView = [SCWorkBenchTopView loadWorkBenchTopView];
    self.topView.frame = CGRectMake(0, 0, SCREEN_WIDTH, 44+SCStatusBarHeight);
    [self.view addSubview:self.topView];
}

- (void)setupView {
    self.view.backgroundColor = SC_BACKGROUD_COLOR;
    //设置tableView的top是从0px开始计算
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:[UITableViewCell sc_className]];
    [self.tableView registerCellWithCellName:[SCWorkBenchFunctionTableCell sc_className]];
    [self.tableView registerCellWithCellName:[SCWorkBenchJobTableCell sc_className]];
    [self.tableView registerClass:[SCWorkBenchTableHeaderView class] forHeaderFooterViewReuseIdentifier:[SCWorkBenchTableHeaderView sc_className]];
    
    [self setTableRefreshHeader];
    [self setAddWorkButtonStyle];
    self.addWorkButton.hidden = YES;
}

- (void)setupData {
    @weakify(self)
    // 点击头像
    self.topView.avatorButtonAction = ^{
        @strongify(self)
        [self showUserProfileController];
    };
    // 点击搜索
    self.topView.textChecked = ^{
        @strongify(self)
        [self jumpToSearchController];
    };
    // 点击扫一扫
    self.topView.scanButtonAction = ^{
        @strongify(self)
        [self jumpToScanController];
    };
    
    /// 头像修改成功后，要刷新头像
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refshreTopView)
                                                 name:kHeadImgModifySuccessNotification object:nil];
    
    /// 设置提醒，更新后，要刷新首页数据
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refshreData)
                                                 name:kRemindSettingSubmitNotification object:nil];
}

// 设置下拉刷新控件
- (void)setTableRefreshHeader {
    @weakify(self)
    MJRefreshNormalHeader *refreshHeader = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        @strongify(self)
        [self workBenchRefreshData];
    }];
    // 修改下拉刷新的时间显示
    refreshHeader.lastUpdatedTimeText = ^NSString *(NSDate *lastUpdatedTime) {
        return SCCompareRefreshDate(lastUpdatedTime);
    };
    self.tableView.mj_header = refreshHeader;
    [self.tableView.mj_header beginRefreshing];
}

// 设置FooterView
- (void)setTableViewFooterView {
    if ((self.benchToDoArray.count == 0) && (self.benchPlanArray.count == 0)) {
        CGFloat height = [SCWorkBenchFunctionTableCell cellHeightForData:self.allAppsListModel.commonApplication];
        self.emptyView.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT-height-SCHomeIndicatorHeight-self.tabBarController.tabBar.bounds.size.height);
        self.tableView.tableFooterView = self.emptyView;
    } else {
        self.tableView.tableFooterView = [UIView new];
    }
}

// 刷新部分UI
- (void)reloadUI {
    [self.tableView reloadData];
    self.addWorkButton.hidden = !([SCMenuItemManager gainPlusItems].count > 0) ;
    [self setTableViewFooterView];
}

// 刷新数据方法
- (void)workBenchRefreshData {
    self.lastFetchedOnDate = [NSDate date];
    // 为了本地缓存的默认园区不影响首页接口，每次回到首页的时候，都重新配置下网络参数
    [[SCUser currentLoggedInUser] configSwitchType];
    dispatch_queue_t homeQueue = dispatch_queue_create("workBenchRefreshData", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    // 获取用户信息数据
    dispatch_group_async(group, homeQueue, ^{
        dispatch_group_enter(group);
        [self fetchUserInfoData:^{
            dispatch_group_leave(group);
        }];
    });
    // 获取全部应用数据
    dispatch_group_async(group, homeQueue, ^{
        dispatch_group_enter(group);
        [self fetchAllServiceData:^{
            dispatch_group_leave(group);
        }];
    });
    // 获取待办数据
    dispatch_group_async(group, homeQueue, ^{
        dispatch_group_enter(group);
        [self fetchWorkTaskData:SCWorkBenchDataTypeNeed complete:^{
            dispatch_group_leave(group);
        }];
    });
    // 获取计划数据
    dispatch_group_async(group, homeQueue, ^{
        dispatch_group_enter(group);
        [self fetchWorkTaskData:SCWorkBenchDataTypePlan complete:^{
            dispatch_group_leave(group);
        }];
    });
    // 获取其他数据 不需要等待获取成功后再刷新首页
    dispatch_group_async(group, homeQueue, ^{
        // 检查版本更新
        [[SCCheckVersion sharedInstance] checkVersion];
        // 获取常用权限
        [SCWorkBanchManager fetchAppCommonAuth];
        // 获取装修阶段数据
        [SCDecorationStageAPI fetchStageItems:nil];
        // 更新报事类型
        [SCReportDataManager updateReportTypeData:nil];
        // 获取未读通知数量
        [SCWorkBanchManager fetchUnReadNoticeNumComplete:nil];
        // 获取巡查要点和分类
        [SCPatrolManager fetchPatrolManagerPointSuccess:nil];
        [SCPatrolManager fetchPatrolManagerCategorySuccess:nil];
        // 当选择的是具体项目园区的时候，获取组团数据
        if ([SCUser currentLoggedInUser].switchType == SCAddressSwitchTypeProject) {
            [SCWorkBanchManager fetchGroupMenuItems:nil];
        }
    });
    // 处理数据、刷新UI
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self.tableView.mj_header endRefreshing];
        [self updateTopViewNoticeStatus];
        self.topView.user = [SCUser currentLoggedInUser];
        [self reloadUI];
    });
}

// 获取用户信息
- (void)fetchUserInfoData:(void(^)(void))complete {
    [SCWorkBanchManager fetchUserInfoSuccess:^{
        !complete?:complete();
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
        !complete?:complete();
    }];
}

// 获取全部应用数据
- (void)fetchAllServiceData:(void(^)(void))complete {
    [SCWorkBanchManager fetchAllServiceMenuSuccess:^(SCMineAllAppsListModel *mineAllAppsListModel) {
        self.allAppsListModel = mineAllAppsListModel;
        !complete?:complete();
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
        !complete?:complete();
    }];
}

// 获取待办、计划任务数据
- (void)fetchWorkTaskData:(SCWorkBenchDataType)workType complete:(void(^)(void))complete {
    [SCWorkBanchManager fetchWorkBenchTastDataWithType:workType success:^(NSMutableArray<SCWorkBenchTaskModel *> *tastData) {
        if (workType == SCWorkBenchDataTypeNeed) {
            self.benchToDoArray = tastData;
        } else if (workType == SCWorkBenchDataTypePlan) {
            self.benchPlanArray = tastData;
        }
        !complete?:complete();
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
        !complete?:complete();
    }];
}

// 获取未读数量
- (void)fetchUnReadNoticeNumber {
    [self updateTopViewNoticeStatus];
    @weakify(self)
    [SCWorkBanchManager fetchUnReadNoticeNumComplete:^{
        @strongify(self)
        [self updateTopViewNoticeStatus];
    }];
}

// 更新小红点
- (void)updateTopViewNoticeStatus {
    NSInteger unreadNoticeCount = [SCGlobalDataManager sharedInstance].unReadNoticeCount;
    NSInteger uploadNum = [SCWorkBanchManager fetchTotalUploadCount];
    if (unreadNoticeCount > 0 || uploadNum > 0) {
        self.topView.showPoint = YES;
    } else {
        self.topView.showPoint = NO;
    }
}

#pragma mark - UITableViewDelegate, UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // 功能、待办、计划 三个section
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return self.benchToDoArray.count;
    if (section == 2) return self.benchPlanArray.count;
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return [SCWorkBenchFunctionTableCell cellHeightForData:self.allAppsListModel.commonApplication];
    return SCWorkBenchJobTableCellHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ((section == 1) && (self.benchToDoArray.count > 0)) return SCWorkBenchTableHeaderViewHeight;
    if ((section == 2) && (self.benchPlanArray.count > 0)) return SCWorkBenchTableHeaderViewHeight;
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    /// 避免被+号按钮遮挡
    if (section == 2 && ((self.benchToDoArray.count > 0) || (self.benchPlanArray.count > 0))) return 80.0f;
    return CGFLOAT_MIN;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section > 0) {
        SCWorkBenchTableHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[SCWorkBenchTableHeaderView sc_className]];
        if (section == 1) { // 待办的section
            [header configMark:@"待办" desc:@""];
        } else if (section == 2) { // 计划的section
            NSDate *tomorrowDate = [CalendarHelper getDayForDate:[NSDate date] difference:1];
            NSString *desc = [NSString stringWithFormat:@"截止:%@", [CalendarHelper convertStringFromDate:tomorrowDate type:@"yyyy-MM-dd"]];
            [header configMark:@"计划" desc:desc];
        }
        return header;
    }
    return [UIView new];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        SCWorkBenchFunctionTableCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCWorkBenchFunctionTableCell sc_className] forIndexPath:indexPath];
        [cell loadData:self.allAppsListModel.commonApplication user:[SCUser currentLoggedInUser]];
        @weakify(self)
        // 选择园区事件
        [cell setChangeCommunityBlock:^{
            @strongify(self)
            [self changeCommunityAction];
        }];
        // 功能点击事件
        [cell setSelectItemBlock:^(SCMenuItem *item) {
            @strongify(self)
            [self selectItemAction:item];
        }];
        return cell;
    }
    // 待办/计划cell
    SCWorkBenchJobTableCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCWorkBenchJobTableCell sc_className] forIndexPath:indexPath];
    NSMutableArray *result;
    if (indexPath.section == 1) {
        result = self.benchToDoArray;
    } else if (indexPath.section == 2) {
        result = self.benchPlanArray;
    }
    cell.benchTask = result[indexPath.row];
    @weakify(self)
    cell.workJobChicked = ^(SCWorkBenchTaskModel *model) {
        @strongify(self)
        [self workJobChicked:model indexPath:indexPath];
    };
    if (result.count == 1) {
        cell.cellType = SCWorkBenchJobTableCellTypeAll;
        [cell setBottomLineHidden:YES];
    } else {
        if (indexPath.row == 0) {
            cell.cellType = SCWorkBenchJobTableCellTypeTop;
            [cell setBottomLineHidden:NO];
        } else if (indexPath.row == result.count -1) {
            cell.cellType = SCWorkBenchJobTableCellTypeBottom;
            [cell setBottomLineHidden:YES];
        } else {
            cell.cellType = SCWorkBenchJobTableCellTypeMiddle;
            [cell setBottomLineHidden:NO];
        }
    }
    return cell;
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    //当下拉刷新的时候，头部跟着一起下拉
    CGFloat y = scrollView.contentOffset.y;
    if (y < 0) {
        self.topView.top = -y;
    } else {
        self.topView.top = 0;
    }
}

#pragma mark - Action
// 设置添加按钮UI
- (void)setAddWorkButtonStyle {
    self.addWorkButton.layer.masksToBounds = YES;
    self.addWorkButton.layer.cornerRadius = 25.0f;
    self.addWorkButton.layer.borderWidth = 1.0f;
    self.addWorkButton.layer.borderColor = [SC_APP_THEME_COLOR CGColor];
    [self.addWorkButton setBackgroundColor:SC_APP_THEME_COLOR];
}

/// 头像更新后，刷新头像显示
- (void)refshreTopView {
    self.topView.user = [SCUser currentLoggedInUser];
}

/// 设置提醒，更新后，要刷新首页数据
- (void)refshreData {
    [self.tableView.mj_header beginRefreshing];
}

// 显示个人信息页
- (void)showUserProfileController {
    // 添加事件统计
    [SCTrackManager trackEvent:kWorkbenchUserAvatarClick];
    /// 是左侧菜单，置为yes
    self.drawerShow = YES;
    /// 侧滑的VC  需要在VC的 viewDidLayoutSubviews 函数里设置下 self.view.width = xxx; 和conf.distance相等即可
    SCSettingsViewController *vc = [[SCSettingsViewController alloc] initWithNibName:[SCSettingsViewController sc_className] bundle:nil];
    vc.drawerShow = YES;
    /// 配置侧滑VC的显示
    CWLateralSlideConfiguration *conf = [CWLateralSlideConfiguration defaultConfiguration];
    /// 根控制器可偏移的距离
    conf.distance = SCLeftDrawerWidth();
    /// 遮罩的透明度
    conf.maskAlpha = 0.1;
    
    // 调用这个方法
    [self cw_showDrawerViewController:vc animationType:CWDrawerAnimationTypeDefault configuration:conf];
}

// 点击功能跳转事件
- (void)selectItemAction:(SCMenuItem *)item {
    if (item.isAllServiceItem) {
        // 全部功能跳转
        [SCTrackManager trackEvent:kWorkbenchAllAppsClick];
        SCAllAppsController *vc = [[SCAllAppsController alloc] initWithNibName:[SCAllAppsController sc_className] bundle:nil];
        vc.allAppsListModel = self.allAppsListModel;
        @weakify(self)
        vc.mineAppChangeBlock = ^(SCMineAllAppsListModel *appsListModel) {
            @strongify(self)
            [self.tableView setContentOffset:CGPointMake(0, 0)];
            self.allAppsListModel = appsListModel;
            [self reloadUI];
        };
        vc.dataChangeBlock = ^{
            @strongify(self)
            // 全部应用页面中最近使用有服务是服务器返回数据没有的，要重新判断+号按钮
            self.addWorkButton.hidden = !([SCMenuItemManager gainPlusItems].count > 0) ;
        };
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        // 储存点击的menuItem
        [SCMenuItemManager dealWithServiceSelectedWithModel:item];
        // 功能跳转
        [[SCMenuItemManager sharedInstance] menuItemSelectedHandle:item onController:self];
        // 添加统计
        [SCTrackManager trackEvent:kWorkbenchCommonAppClick attributes:@{@"modelName":item.title}];
    }
}

// 跳转到搜索页
- (void)jumpToSearchController {
    SCWorkBenchSearchViewController *target = [[SCWorkBenchSearchViewController alloc] initWithNibName:[SCWorkBenchSearchViewController sc_className] bundle:nil];
    SCBaseNavigationController *nav = [[SCBaseNavigationController alloc] initWithRootViewController:target];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
    // 添加事件统计
    [SCTrackManager trackEvent:kWorkbenchSearchBarClick];
}

// 跳转到扫一扫页
- (void)jumpToScanController {
    // 功能跳转
    [[SCMenuItemManager sharedInstance] menuItemSelectedHandle:[SCMenuItemManager homeScanMenuItem] onController:self];
    // 添加事件统计
    [SCTrackManager trackEvent:kWorkbenchScanClick];
}

// 选择园区按钮跳转事件
- (void)changeCommunityAction {
    if ([self.tableView.mj_header isRefreshing]) {
        // 正在刷新的时候，不能切换园区
        return;
    }
    if (([SCUser currentLoggedInUser].userType == SCUserTypeGroupAdmin) || ([SCUser currentLoggedInUser].userType == SCUserTypeCompanyAdmin)) {
        // 添加统计
        [SCTrackManager trackEvent:kWorkbenchSwitchAddressClick attributes:@{@"accountId":[SCUser currentLoggedInUser].userId}];
        // 只有分子公司账号和集团账号才会选择园区
        SCAddressSwitchModel *addressModel = [[SCAddressSwitchModel alloc] init];
        addressModel.addressId = [SCUser currentLoggedInUser].selOrgId;
        addressModel.addressName = [SCUser currentLoggedInUser].selOrgName;
        addressModel.addresstype = [SCUser currentLoggedInUser].switchType;
        SCSwitchAddressViewController *target = [SCSwitchAddressViewController addressViewControllerWithCurrentAddress:addressModel];
        @weakify(self)
        target.addressSelectedBlock = ^(SCAddressSwitchModel *address) {
            @strongify(self)
            [SCWorkBanchManager changeAddressHandel:address];
            [[NSNotificationCenter defaultCenter] postNotificationName:kModifyCommunityNotification object:nil];
            [self.tableView.mj_header beginRefreshing];
        };
        [self.navigationController pushViewController:target animated:YES];
    }
}

// 点击待办/计划跳转事件
- (void)workJobChicked:(SCWorkBenchTaskModel *)workJob indexPath:(NSIndexPath *)indexPath {
    if ([SCUser currentLoggedInUser].switchType == SCAddressSwitchTypeProject) {
        // 选的是项目 ，直接跳转 需要获取下组团数据
        NSDictionary *userInfo = @{ SCRouterParameterUserInfoNavigationVC: self.navigationController,
                                    SCRouterParameterUserInfoViewController:self,
                                    @"workJobType":workJob.type,
                                  };
        [SCViewRouterManager showViewByRouterDict:workJob.skipData userInfoDic:userInfo];
    } else {
        // 选择的不是项目，则跳中间页
        SCSelectProjectController *VC = [[SCSelectProjectController alloc] initWithNibName:[SCSelectProjectController sc_className] bundle:nil];
        VC.model = workJob;
        [self.navigationController pushViewController:VC animated:YES];
    }
    // 添加统计方法
    if (indexPath.section == 1) {
        [SCTrackManager trackEvent:kWorkbenchTodoTaskClick attributes:@{@"taskName":workJob.taskTitle}];
    } else if (indexPath.section == 2) {
        [SCTrackManager trackEvent:kWorkbenchPlanTaskClick attributes:@{@"taskName":workJob.taskTitle}];
    }
}

// 添加工作按钮事件
- (IBAction)addWorkButtonAction:(id)sender {
    
    NSMutableArray *plusItems = [SCMenuItemManager gainPlusItems];
    
    if (!_plusView) {
        _plusView = [[SCWorkBenchAddView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    if (plusItems.count > 0) {
        [self.plusView show];
        self.plusView.dataArray = plusItems;
        @weakify(self);
        self.plusView.selectBlock = ^(NSInteger index) {
            @strongify(self)
            // 统计
            SCMenuItem *item = plusItems[index];
            [SCTrackManager trackEvent:kWorkbenchAddItemClick attributes:@{@"itemName":item.title}];
            [[SCMenuItemManager sharedInstance] menuItemSelectedHandle:item onController:self];
        };
    }
    // 统计
    [SCTrackManager trackEvent:kWorkbenchPostButtonClick];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
