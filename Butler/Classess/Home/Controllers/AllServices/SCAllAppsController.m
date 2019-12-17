//
//  SCAllAppsController.m
//  Butler
//
//  Created by sunyongguang on 2018/6/13.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//  全部应用页面

#import "SCAllAppsController.h"

/// vc

/// view
#import "SCMyServicesCell.h"
#import "SCAllServicesListCell.h"
/// model
#import "SCMenuItem.h"
#import "SCAllAppCategoryModel.h"
#import "SCMineAllAppsListModel.h"
/// api
#import "SCAllServiceListAPI.h"
#import "SCSetMyServiceAPI.h"
/// other
#import "SCMenuItemManager.h"
#import "SCWorkBanchManager.h"

@interface SCAllAppsController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

/// 我的应用的cell
@property (nonatomic, strong) SCMyServicesCell *myServicesCell;
/// 本地储存的最近使用的数据
@property (nonatomic, strong) NSMutableArray  *localArray;
/// 我的应用是否改变标识
@property (nonatomic, assign) BOOL isMineAppsChanged;
/// 是否要删除最近使用数据（防止返回上一页面，污染上一页面数据）
@property (nonatomic, assign) BOOL deleteLocal;

@end

@implementation SCAllAppsController

#pragma mark - 生命周期方法
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNav];
    [self setupData];
    [self setupView];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.deleteLocal) {
        [self deleteLocalData];
    }
    /// 取消编辑状态
    [self configureAppSelectedStatus:NO];
    /// 如果有修改，返回刷新数据
    if (self.mineAppChangeBlock && self.isMineAppsChanged) {
        self.mineAppChangeBlock(self.allAppsListModel);
        self.isMineAppsChanged = NO;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    /// 默认是删除本地
    self.deleteLocal = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 固定方法
- (void)setupNav {
    self.navigationItem.title = @"全部应用";
}

- (void)setupView {
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0.0, 0.0, SCREEN_WIDTH, SCREEN_HEIGHT);
    gradient.colors = @[(__bridge id)[SC_NAVBAR_END_COLOR CGColor], (__bridge id)[HEXCOLOR(0x34526F) CGColor]];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(0, 1);
    [self.view.layer addSublayer:gradient];
    /// 要把tableView显示到最前
    [self.view bringSubviewToFront:self.tableView];
    
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self registerTableViewCell];
    
    /// 下拉刷新控件
    [self setUpRefreshHeaderFooter];
}

- (void)setupData {
    //将本地数据加入显示
    [self showRecentUseServices];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appStatusButtonClickAction:) name:kAppStatusButtonClickNotification object:nil];
}

#pragma mark - 代理方法 Delegate Methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.allAppsListModel ? 2 : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        SCMyServicesCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCMyServicesCell sc_className] forIndexPath:indexPath];
        @weakify(self);
        cell.editBtnClickBlock = ^(BOOL isClicked) {
            @strongify(self);
            /// 处理编辑按钮事件
            if (!isClicked) {
                [self requestForSetMyService];
            } else {
                [self configureAppSelectedStatus:isClicked];
            }
        };
        cell.appTapActionBlock = ^(SCMenuItem *menuItem) {
            @strongify(self);
            /// 功能跳转的处理
            [self actionForPushToOtherVCWith:menuItem];
        };
        [cell loadData:self.allAppsListModel.commonApplication];
        self.myServicesCell = cell;
        return cell;
        
    } else {
        SCAllServicesListCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCAllServicesListCell sc_className] forIndexPath:indexPath];
        @weakify(self);
        //应用跳转
        cell.appTapActionBlock = ^(SCMenuItem *menuItem) {
            @strongify(self);
            
            if (menuItem.onlyLocal) {
                /// 是本地的，全部应用不存在的，需要提示个气泡
                [SVProgressHUD showErrorWithStatus:@"对不起，你无该模块权限" duration:1.5 dismiss:nil];
            } else {
                /// 跳转的处理
                [self actionForPushToOtherVCWith:menuItem];
            }
        };
        
        [cell loadData:self.allAppsListModel.allApplication];
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 226.f;
    } else {
        return SCREEN_HEIGHT - 226.f - SCStatusBarHeight - 44.f;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section  {
    return CGFLOAT_MIN;
}


#pragma mark - 布局UI  LayoutUI Methods

#pragma mark - 对外方法 Public Methods
#pragma mark - 内部方法 Private Methods
// 注册cell
- (void)registerTableViewCell {
    
    [self.tableView registerNib:[UINib nibWithNibName:[SCMyServicesCell sc_className] bundle:nil] forCellReuseIdentifier:[SCMyServicesCell sc_className]];
    [self.tableView registerNib:[UINib nibWithNibName:[SCAllServicesListCell sc_className] bundle:nil] forCellReuseIdentifier:[SCAllServicesListCell sc_className]];
}


// 添加刷新控件
- (void)setUpRefreshHeaderFooter {
    
    @weakify(self);
    self.tableView.mj_header = [SCCustomRefreshHeader headerWithRefreshingBlock:^{
        @strongify(self);
        [self requestForGetAllService];
    }];
    
    if (!self.allAppsListModel) {
        /// 如果首页获取数据失败，进入本页面，需要自动刷新
        [self.tableView.mj_header beginRefreshing];
    }
}

/// 获取全部应用
- (void)requestForGetAllService {
    
    @weakify(self);
    [SCWorkBanchManager fetchAllServiceMenuSuccess:^(SCMineAllAppsListModel *mineAllAppsListModel) {
        @strongify(self);
        [self.tableView.mj_header endRefreshing];
        self.allAppsListModel = mineAllAppsListModel;
        [self showRecentUseServices];
        [self configureAppSelectedStatus:NO];
        
    } failure:^(NSError *error) {
        [self.tableView.mj_header endRefreshing];
        [SCAlertHelper handleError:error];
    }];
}

/// 设置我的应用请求
- (void)requestForSetMyService {
    
    if (!self.allAppsListModel) {
        return;
    }
    // 设置参数
    NSMutableArray *codeArr = [NSMutableArray array];
    NSMutableArray *nameArr = [NSMutableArray array];
    [self.allAppsListModel.commonApplication enumerateObjectsUsingBlock:^(SCMenuItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [codeArr addObject:ISNULL(obj.code)];
        [nameArr addObject:ISNULL(obj.title)];
    }];
    // 统计
    [SCTrackManager trackEvent:kWorkbenchAllAppsCompleteClick attributes:@{@"appNames":[nameArr componentsJoinedByString:@","]}];
    // 请求
    SCSetMyServiceAPI *setMyServiceAPI = [[SCSetMyServiceAPI alloc] init];
    setMyServiceAPI.menuCodes = codeArr;
    [SVProgressHUD show];
    [setMyServiceAPI startWithCompletionWithSuccess:^(id responseDataDict) {
        [SVProgressHUD showSuccessWithStatus:@"设置成功" duration:1.5 dismiss:nil];
        self.isMineAppsChanged = YES;
        [self.myServicesCell saveMyAppsResult:YES];
        [self configureAppSelectedStatus:NO];
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
        [self.myServicesCell saveMyAppsResult:NO];
    }];
}

/**
 设置所有应用的编辑状态
 
 @param isEditing 是否在编辑中
 */
- (void)configureAppSelectedStatus:(BOOL)isEditing {
    // 统计
    [SCTrackManager trackEvent:kWorkbenchAllAppsEditClick];
    self.tableView.mj_header.hidden = isEditing;
    
    NSMutableArray *allAppIdsMArray = [[NSMutableArray alloc] initWithCapacity:1];
    [self.allAppsListModel.commonApplication enumerateObjectsUsingBlock:^(SCMenuItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (isEditing) {
            obj.appSelectedStatus = SCAppSelectedStatusMinus;
            [allAppIdsMArray addObject:obj.code];
        } else {
            obj.appSelectedStatus = SCAppSelectedStatusNormal;
        }
        
    }];
    
    [self.allAppsListModel.allApplication enumerateObjectsUsingBlock:^(SCAllAppCategoryModel *allAppCategoryModel, NSUInteger idx, BOOL * _Nonnull stop) {
        [allAppCategoryModel.moduleList enumerateObjectsUsingBlock:^(SCMenuItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if (!isEditing) {
                obj.appSelectedStatus = SCAppSelectedStatusNormal;
            }
            else if ([allAppIdsMArray containsObject:obj.code]) {
                obj.appSelectedStatus = SCAppSelectedStatusSelected;
            } else {
                obj.appSelectedStatus = SCAppSelectedStatusNone;
            }
        }];
    }];
    
   [self.tableView reloadData];
}

/// 加减按钮点击的通知
- (void)appStatusButtonClickAction:(NSNotification *)notification {
    
    SCMenuItem *serviceItem = (SCMenuItem *)notification.object;
    if ([serviceItem isKindOfClass:[SCMenuItem class]]) {
        switch (serviceItem.appSelectedStatus) {
            case SCAppSelectedStatusNone: //添加应用到我的应用中
            {
                if (self.allAppsListModel.commonApplication.count < 7) {
                    [self.allAppsListModel.commonApplication addObject:[serviceItem copy]];
                    [self configureAppSelectedStatus:YES];
                } else {
                    [SVProgressHUD showErrorWithStatus:@"首页最多添加7个应用" duration:1.5 dismiss:nil];
                }
            }
                break;
            case SCAppSelectedStatusMinus: //将应用从我的应用中移除
            {
                if (self.allAppsListModel.commonApplication.count > 0) {
                    [self.allAppsListModel.commonApplication removeObject:serviceItem];
                    [self configureAppSelectedStatus:YES];
                }
            }
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - 处理最近使用应用

/// 显示最近使用 recent use
- (void)showRecentUseServices {
    
    if (!self.allAppsListModel) {
        /// 没有数据 就不进行处理
        return;
    }
    
    /// 以防数据有最近使用，先删除掉
    [self deleteLocalData];
    /// 先获取最近使用本地缓存数据
    self.localArray = [SCMenuItem gainAllLocalServicesData];
    
    if (self.localArray.count > 0) {
        /// 全部应用比较
        [self.localArray enumerateObjectsUsingBlock:^(SCMenuItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self containInAllServicesWithModel:obj];
        }];
        
        // 修改bug  22450 【小邑管家】【iOS】【全部应用】后台关闭最近使用的应用后，APP端编辑添加到常用应用，还能继续使用，且会显示至首页；按照产品最终确定，过滤掉没权限的模块
        NSMutableArray *tempArr = [self.localArray mutableCopy];
        /// mutableCopy一下，防止数据污染
        [tempArr enumerateObjectsUsingBlock:^(SCMenuItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.onlyLocal) {
                [self.localArray removeObject:obj];
            }
        }];
        
        /// 更新下存储
        [SCMenuItem saveServicesData:self.localArray];
    }

    
    if (self.allAppsListModel) {
        /// 将本地最近使用数据 加到从网络上返回的数据内
        SCAllAppCategoryModel *localModel = [[SCAllAppCategoryModel alloc] init];
        localModel.moduleName = @"最近使用";
        localModel.moduleList = self.localArray;
        localModel.local = YES;
        if (self.allAppsListModel.allApplication.count > 0) {
            
            [self.allAppsListModel.allApplication insertObject:localModel atIndex:0];
        } else {
            self.allAppsListModel.allApplication = [NSMutableArray arrayWithArray:@[localModel]];
        }
    }
}

/// 查询本地应用在全部应用中 是否存在
- (void)containInAllServicesWithModel:(SCMenuItem *)model {
    /// 包含，替换；不包含，标记为本地
    
    NSInteger index = [self.localArray indexOfObject:model];
    __block BOOL contain = NO;
    
    [self.allAppsListModel.allApplication enumerateObjectsUsingBlock:^(SCAllAppCategoryModel *allAppCategoryModel, NSUInteger idx, BOOL * _Nonnull stop) {
        [allAppCategoryModel.moduleList enumerateObjectsUsingBlock:^(SCMenuItem *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([ISNULL(model.code) isEqualToString:ISNULL(obj.code)]) {
                /// 如果相等 替换，为了展示的是最新的数据
                contain = YES;
                [self.localArray replaceObjectAtIndex:index withObject:[obj copy]];
                *stop = YES;
            }
        }];
    }];
    
    if (!contain) {
        /// 不包含,代表全部应用里面没有此模块，只有本地存在
        model.onlyLocal = YES;
        /// 首页+号按钮的显示，可能改变
        if (self.dataChangeBlock) {
            self.dataChangeBlock();
        }
    }
}

/// 将最近使用数据从allAppsListModel删除
- (void)deleteLocalData {
    
    if (self.allAppsListModel && self.allAppsListModel.allApplication.count > 0) {
        
        /// mutableCopy这样防止数据污染
        NSMutableArray *tempArray = [self.allAppsListModel.allApplication mutableCopy];
        @weakify(self)
        [tempArray enumerateObjectsUsingBlock:^(SCAllAppCategoryModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            @strongify(self);
            if (obj.local) {
                // 最近使用，则从allAppsListModel删除掉，以防返重复显示最近使用数据
                [self.allAppsListModel.allApplication removeObject:obj];
            }
        }];
    }
}

#pragma mark - 点击/触碰事件 Action Methods

- (void)actionForPushToOtherVCWith:(SCMenuItem *)menuItem {
    /// 跳转到下一页面，不删除最近使用数据
    self.deleteLocal = NO;
    /// 储存点击的menuItem
    [SCMenuItemManager dealWithServiceSelectedWithModel:menuItem];
    /// 处理跳转
    [[SCMenuItemManager sharedInstance] menuItemSelectedHandle:menuItem onController:self];
    /// 统计
    [SCTrackManager trackEvent:kWorkbenchAllAppsAppClick attributes:@{@"appName":menuItem.title}];
}

#pragma mark - 懒加载 Lazy Load


@end
