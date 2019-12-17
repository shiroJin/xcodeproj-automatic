//
//  SCDevicePatrolListViewController.m
//  Butler
//
//  Created by abeihaha on 2017/1/4.
//  Copyright © 2017年 UAMA Inc. All rights reserved.
//

#import "SCDevicePatrolListViewController.h"

#import "SCDevicePatrolListViewController.h"
#import "SCDevicePatrolSelectViewController.h"
#import "SCDevicePatrolFBViewController.h"
#import "SCDevicePatrolDetailViewController.h"
#import "SCQRScanViewController.h"

#import "UITableView+FDTemplateLayoutCell.h"
#import "SCDevicePatrolViewCell.h"
#import "SCDevicePatrolGroupHeaderViewCell.h"

#import "SCBLECentralManager.h"
#import "SCDevicePatrolSectionDBItem.h"
#import "SCDevicePatrolCellDBItem.h"
#import "SCBeaconManager.h"
#import "SCDevicePatrolSectionDBItem.h"
#import "SCDevicePatrolCellDBItem.h"
#import "SCDevicePatrolManager.h"

#import <AFNetworking/AFNetworkReachabilityManager.h>

@interface SCDevicePatrolListViewController ()<UITableViewDelegate, UITableViewDataSource>
{
    
    // 通知对象
    id _selectionObserver;
    id _changeObserver;
}
@property (weak, nonatomic) IBOutlet UITableView *tableView;

// 数据源
@property (strong, nonatomic) NSMutableArray<SCDevicePatrolSectionDBItem *> *items;
// 这个是用来获取列表数据的
@property (strong, nonatomic) SCDevicePatrolManager *patrolManager;
// 这个是用来查询离线数据库的
@property (strong, nonatomic) SCDevicePatrolManager *dBManager;
// 组团
@property (strong, nonatomic) NSString *groupID;
// 是否是筛选按钮操作：只有当有筛选条件且点了筛选确定按钮时才算是筛选，手动下拉刷新都需要请求网络更新数据
@property (assign, nonatomic) BOOL isFilter;
// 被巡检组
@property (assign, nonatomic) NSInteger selectedIndex;
// 被选择的QRCode
@property (strong, nonatomic) NSString *selQRCode;

@property (strong, nonatomic) NSMutableArray *selectDistributeArr;

@end

@implementation SCDevicePatrolListViewController

- (SCDevicePatrolManager *)patrolManager {
    if (!_patrolManager) {
        _patrolManager = [[SCDevicePatrolManager alloc] init];
    }
    return _patrolManager;
}

- (SCDevicePatrolManager *)dBManager {
    if (!_dBManager) {
        _dBManager = [[SCDevicePatrolManager alloc] init];
    }
    return _dBManager;
}

- (NSMutableArray *)items {
    if (!_items) {
        _items = [NSMutableArray new];
    }
    return _items;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
    [self setupData];
}

- (void)setupView {
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerCellWithCellName:@"SCDevicePatrolViewCell"];
    [self.tableView registerCellWithCellName:@"SCDevicePatrolGroupHeaderViewCell"];
    self.tableView.estimatedRowHeight = 74.0f;
}

- (NSString *)patrolStatus {
    return !_patrolStatus ? @"":_patrolStatus;
}

- (void)setupData {
    // 初始化配置
    self.groupID = @"";
    if (self.selParams) {
        self.groupID = [self.selParams valueForKey:@"groupID"];
        self.patrolStatus = [self.selParams valueForKey:@"patrolStatus"];
    }
    @weakify(self)
    self.tableView.mj_header= [SCCustomRefreshHeader headerWithRefreshingBlock:^{
        @strongify(self)
        if (self.timeTag == 1) {
            // 有网状态下且不是筛选操作，才需要请求接口更新数据
            if ([[AFNetworkReachabilityManager sharedManager] isReachable] && !self.isFilter) {
                [self fetchDevicePatrolDB];
            } else {
                [self loadItems:self.isFilter];
            }
        } else {
            [self loadItems:self.isFilter];
        }
    }];
    self.tableView.mj_footer = [SCCustomRefreshFooter footerWithRefreshingBlock:^{
        @strongify(self)
        [self loadMoreItems:self.isFilter];
    }];
    [self.tableView.mj_footer endRefreshingWithNoMoreData];
    [self.tableView.mj_header beginRefreshing];
    self.selectDistributeArr = [NSMutableArray array];
    [self addNotificationHandleMethod];
}

#pragma mark - Notification Handle Method
// 收到通知后处理
- (void)addNotificationHandleMethod {
    @weakify(self)
    //筛选框选择后通知，如果是筛选操作则不需要更新离线数据
    _selectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"MenuSelection" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        @strongify(self)
        self.selParams = [note userInfo];
        if (self.selParams) {
            self.patrolStatus = self.selParams[@"patrolStatus"];
            self.groupID = self.selParams[@"groupID"];
        }
        [self.tableView.mj_header beginRefreshing];
    }];
    _changeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kDevicePatrolItemChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        @strongify(self)
        if (self.timeTag == 1) {
            [self.tableView.mj_header beginRefreshing];
        }
    }];
}

/**
 数据有变化，重新请求网络，更新数据
 */
- (void)reloadData {
    [self.tableView.mj_header beginRefreshing];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:_selectionObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_changeObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 是否有筛选条件
- (BOOL)isFilter
{
    return (self.patrolStatus.length > 0) || (self.groupID.length >0);
}

// 刷新UI
- (void)reloadUI {
    if (self.items.count == 0) {
        [SCEmptyDataSetAssistant emptyForContentView:self.tableView builderBlock:^(SCEmptyDataSetBuilder *builder) {
            builder.emptyTitle = @"暂无巡检信息";
        } tappedBlock:nil];
    }
    if (![self.patrolManager.page hasMore]) {
        [self.tableView.mj_footer endRefreshingWithNoMoreData];
    } else {
        [self.tableView.mj_footer resetNoMoreData];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DevicePatrolDataFetched" object:nil];
    [self.tableView reloadData];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)setBeginDistribute:(BOOL)beginDistribute
{
    _beginDistribute = beginDistribute;
    //如果开始分配，隐藏刷新头部和如果有下一页，隐藏footer
    self.tableView.mj_header.hidden = beginDistribute;
    self.tableView.mj_footer.hidden = ([self.patrolManager.page hasMore] && beginDistribute);
    if (!beginDistribute) {
        //取消选择
        for (SCDevicePatrolCellDBItem *cellItem in self.selectDistributeArr) {
            cellItem.selected = NO;
        }
    }
    if (self.timeTag == 1) {
        for (SCDevicePatrolSectionDBItem *section in self.items) {
            section.patrolEnable = !beginDistribute;
        }
    }
    [self.tableView reloadData];
}


#pragma mark - request
// 查询今天的离线数据库是否需要更新 (这个方法只在timeType为1的时候会调用)
- (void)fetchDevicePatrolDB {
    
    [SCCommonHelper presentNetworkAlertViewController:self title:@"下载巡检离线数据" doneBlock:^{
        // 需要下载离线数据的时候，界面不能返回，发通知告诉
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DevicePatrolDBIsUpdating" object:nil];
        @weakify(self)
        [self.dBManager downLoadOfflineDevicePatrolDataInController:self.parentViewController success:^{
            @strongify(self)
            [self loadItems:self.isFilter];
        } failureBlock:^(NSError *error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DevicePatrolDBIsUpdated" object:nil];
            [self failureBlockWithError:error isHeader:YES];
        }];
    } canceBlock:^(NSError *error) {
        [self loadItems:self.isFilter];
    } noNetWorkBlock:^(NSError *error) {
        [self loadItems:self.isFilter];
    }];
}

// 获取第一页数据
- (void)loadItems:(BOOL)isFilter {
    @weakify(self)
    // 离线数据库更新完了，加载离线数据的时候，发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DevicePatrolDBIsUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DevicePatrolDataFetching" object:nil];
    if (isFilter) {
        [self.patrolManager fetchFilterDevicePatrolListWithStatus:self.patrolStatus timeType:self.timeTag groupId:self.groupID name:@"" success:^(NSArray<SCDevicePatrolSectionDBItem *> *items) {
            @strongify(self)
            [self.tableView.mj_header endRefreshing];
            self.items = [items mutableCopy];
            [self reloadUI];
        } failureBlock:^(NSError *error) {
            @strongify(self)
            [self failureBlockWithError:error isHeader:YES];
        }];
    } else {
        [self.patrolManager fetchDevicePatrolListWithStatus:self.patrolStatus timeType:self.timeTag groupId:self.groupID name:@"" success:^(NSArray<SCDevicePatrolSectionDBItem *> *items) {
            @strongify(self)
            [self.tableView.mj_header endRefreshing];
            self.items = [items mutableCopy];
            [self reloadUI];
        } failureBlock:^(NSError *error) {
            @strongify(self)
            [self failureBlockWithError:error isHeader:YES];
        }];
    }
}

// 获取下一页数据
- (void)loadMoreItems:(BOOL)isFilter {
    @weakify(self)
    if (isFilter) {
        [self.patrolManager fetchMoreFilterDevicePatrolListWithTimeType:self.timeTag success:^(NSArray<SCDevicePatrolSectionDBItem *> *items) {
            @strongify(self)
            [self.items addObjectsFromArray:items];
            [self reloadUI];
        } failureBlock:^(NSError *error) {
            @strongify(self)
            [self failureBlockWithError:error isHeader:YES];
        }];
    } else {
        [self.patrolManager fetchMoreDevicePatrolListWithTimeType:self.timeTag success:^(NSArray<SCDevicePatrolSectionDBItem *> *items) {
            @strongify(self)
            [self.items addObjectsFromArray:items];
            [self reloadUI];
        } failureBlock:^(NSError *error) {
            @strongify(self)
            [self failureBlockWithError:error isHeader:YES];
        }];
    }
}

- (void)failureBlockWithError:(NSError *)error isHeader:(BOOL)isHeader
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DevicePatrolDataFetched" object:nil];
    if (isHeader) {
        [self.tableView.mj_header endRefreshing];
    } else {
        [self.tableView.mj_footer endRefreshing];
    }
    [SCAlertHelper handleError:error];
}


#pragma mark - UITableViewDataSource Methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_items count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rowNum = 1;
    SCDevicePatrolSectionDBItem *item = (SCDevicePatrolSectionDBItem *)[_items objectAtIndex:section];
    rowNum += [item.items count];
    return rowNum;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    if (row == 0) {
        SCDevicePatrolGroupHeaderViewCell *cell = [tableView dequeueCellName:NSStringFromClass([SCDevicePatrolGroupHeaderViewCell class]) indexPath:indexPath];
        [self configGroupHeaderCell:cell atIndexPath:indexPath];
        return cell;
    } else {
        SCDevicePatrolViewCell *cell = [tableView dequeueCellName:NSStringFromClass([SCDevicePatrolViewCell class]) indexPath:indexPath];
        [self configPatrolViewCell:cell atIndexPath:indexPath];
        return cell;
    }
    return [UITableViewCell new]; //fixed by 囧 以防崩溃;
}

#pragma mark - UITableViewDelegate Methods
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    if (row != 0) {
        if (section < _items.count) {
            SCDevicePatrolSectionDBItem *item = (SCDevicePatrolSectionDBItem *)self.items[section];
            SCDevicePatrolCellDBItem *cellItem = (SCDevicePatrolCellDBItem *)item.items[row-1];
            if (!self.beginDistribute) {
                if (cellItem.patrolStatus == SCDevicePatrolStatusProcessed) {
                    [self showPatrolDetailVC:cellItem];
                } else if (cellItem.patrolStatus == SCDevicePatrolStatusUpload) {
                    [SVProgressHUD showErrorWithStatus:@"设备已巡检，请尽快上传巡检信息" duration:1.0 dismiss:nil];
                }
            } else {
                if (cellItem.patrolStatus == SCDevicePatrolStatusWaiting || cellItem.patrolStatus == SCDevicePatrolStatusExpire) {
                    cellItem.selected = !cellItem.selected;
                    if (cellItem.selected) {
                        [self.selectDistributeArr addObject:cellItem];
                    } else {
                        if ([self.selectDistributeArr containsObject:cellItem]) {
                            [self.selectDistributeArr removeObject:cellItem];
                        }
                    }
                    if (self.distributeItemClick) {
                        self.distributeItemClick(self.selectDistributeArr);
                    }
                    [self.tableView reloadData];
                }
            }
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 8.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    if (row == 0) {
        return [tableView fd_heightForCellWithIdentifier:@"SCDevicePatrolGroupHeaderViewCell"
                                        cacheByIndexPath:indexPath configuration:^(SCDevicePatrolGroupHeaderViewCell *cell) {
                                            [self configGroupHeaderCell:cell atIndexPath:indexPath];
                                        }];
    } else {
        return SCDevicePatrolViewCellHeight;
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

#pragma mark - Config Cells Methods
- (void)configGroupHeaderCell:(SCDevicePatrolGroupHeaderViewCell *)cell
                  atIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = [indexPath section];
    SCDevicePatrolSectionDBItem *item = (SCDevicePatrolSectionDBItem *)self.items[section];
    @weakify(self)
    [cell setUpWithPatrolSectionItem:item checked:NO beginBLEPatrolBlock:^(NSString *UUID, NSUInteger major, NSUInteger minor) {
        @strongify(self)
        self.selectedIndex = section;
        [self startBLEPatrolUsingUUID:UUID major:major minor:minor];
    } beginQRPatrolBlock:^(NSString *QRCode) {
        @strongify(self)
        self.selectedIndex = section;
        self.selQRCode = QRCode;
        [self startQRPatrol];
    }];
}

- (void)configPatrolViewCell:(SCDevicePatrolViewCell *)cell
                 atIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    SCDevicePatrolSectionDBItem *item = (SCDevicePatrolSectionDBItem *)self.items[section];
    SCDevicePatrolCellDBItem *cellItem = (SCDevicePatrolCellDBItem *)(item.items[row-1]);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell setUpWithItem:cellItem];
    if (self.beginDistribute) {
        if (cellItem.patrolStatus == SCDevicePatrolStatusWaiting || cellItem.patrolStatus == SCDevicePatrolStatusExpire) {
            [cell setUserInteractionEnabled:YES];
        } else {
            [cell setUserInteractionEnabled:NO];
        }
    } else {
        if (cellItem.patrolStatus == SCDevicePatrolStatusProcessed || cellItem.patrolStatus == SCDevicePatrolStatusUpload) {
            [cell setUserInteractionEnabled:YES];
        } else {
            [cell setUserInteractionEnabled:NO];
        }
    }
}

/// 进入设备选择界面
- (void)push2DeviceSelectVC:(SCDevicePatrolType)patrolType {
    SCDevicePatrolSectionDBItem *item = (SCDevicePatrolSectionDBItem *)_items[_selectedIndex];
    item.patrolType = patrolType;
    SCDevicePatrolSelectViewController *selectVC = [[SCDevicePatrolSelectViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolSelectViewController class]) bundle:nil];
    @weakify(self)
    [selectVC setUpWithPatrolSectionItem:item patrolType:patrolType change:^(SCDevicePatrolSectionDBItem *item) {
        @strongify(self)
        if (item) {
            [self.items replaceObjectAtIndex:self.selectedIndex withObject:item];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:self.selectedIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }];
    [self.navigationController pushViewController:selectVC animated:YES];
}

/// 扫描蓝牙失败处理方法
- (void)showBLEScanFailAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleAlert];
    @weakify(self)
    UIAlertAction *cancleAction = [UIAlertAction actionWithTitle:@"继续巡检" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self)
        [self push2DeviceSelectVC:SCDevicePatrolTypeNotBLE];
    }];
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.3) {
        [cancleAction setValue:HEXCOLOR(0x00AE08) forKey:@"titleTextColor"];
    }
    NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:@"找不到蓝牙点，可能是蓝牙数据不规范或蓝牙出现了故障，请及时反馈管理员，并继续执行设备巡检" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17.0f], NSForegroundColorAttributeName:SC_TEXT_THEME_COLOR}];
    [alertController setValue:attributedMessage forKey:@"attributedMessage"];
    [alertController addAction:cancleAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Patrol Methods
// 开始巡检-蓝牙
- (void)startBLEPatrolUsingUUID:(NSString *)UUID major:(NSUInteger)major minor:(NSUInteger)minor {
    if ([[SCBLECentralManager sharedInstance] BLEAvailableIn:self accessType:SCBLEAccessTypeDevicePatrol]) {
        if ([SCBeaconManager GPSAllwaysAuthorizedIn:self]) {
            @weakify(self)
            [SVProgressHUD showWithStatus:@"正在扫描蓝牙"];
            [[SCBeaconManager sharedInstance] scanBeaconUsingUUIDString:UUID major:major minor:minor
                success:^{
                @strongify(self)
                [SVProgressHUD dismiss];
                [self push2DeviceSelectVC:SCDevicePatrolTypeBLE];
            } failure:^(NSError *error) {
                @strongify(self)
                [SVProgressHUD dismiss];
                [self showBLEScanFailAlert];
            }];
        }
    }
}

// 开始巡检-二维码
- (void)startQRPatrol {
    SCQRScanViewController *scanVC = [[SCQRScanViewController alloc] initWithNibName:@"SCQRScanViewController" bundle:nil];
    @weakify(self)
    scanVC.onScanned = ^(NSString *QRCode) {
        @strongify(self)
        // 新增二维码逻辑判断
        if ([QRCode rangeOfString:@"∝"].location != NSNotFound) {
            NSRange range = [QRCode rangeOfString:@"∝"];
            if ([QRCode substringToIndex:range.location].length > 0) {
                QRCode = [QRCode substringToIndex:range.location];
            }
        }
        if ([[QRCode trimAnySpace] length] > 9) {
            QRCode = [QRCode substringToIndex:6];
        }
        if ([QRCode isEqualToString:self.selQRCode]) {
            [self dispatchQRPatrol];
        } else {
            [SVProgressHUD showErrorWithStatus:@"二维码与巡检设备不匹配，请选择正确的二维码进行扫描" duration:1.0 dismiss:nil];
        }
    };
    SCBaseNavigationController *nav = [[SCBaseNavigationController alloc] initWithRootViewController:scanVC];
    nav.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:nav animated:YES completion:^{}];
}

// 根据巡检状态Push到不同的界面
- (void)dispatchQRPatrol {
    if (self.items.count <= _selectedIndex) {
        return;
    }
    SCDevicePatrolSectionDBItem *sectionItem = (SCDevicePatrolSectionDBItem *)self.items[_selectedIndex];
    NSMutableArray *items = [NSMutableArray new];
    [items addObjectsFromArray:sectionItem.items];
    if (items.count == 0) {
        return;
    }
    if ([items count] == 1) {
        SCDevicePatrolCellDBItem *cellItem = (SCDevicePatrolCellDBItem *)items[0];
        cellItem.patrolType = SCDevicePatrolTypeQRCode;
        switch (cellItem.patrolStatus) {
            case SCDevicePatrolStatusExpire:
            case SCDevicePatrolStatusWaiting: {
                if (![cellItem canExecute]) {
                    [SVProgressHUD showErrorWithStatus:@"您不是该任务的执行人" duration:1.5 dismiss:nil];
                    return;
                }
                SCDevicePatrolFBViewController *fbVC = [[SCDevicePatrolFBViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolFBViewController class]) bundle:nil];
                @weakify(self)
                [fbVC setUpWithCellItem:cellItem inSectionItem:sectionItem chage:^(SCDevicePatrolCellDBItem *item) {
                    @strongify(self)
                    if (item) {
                        [items replaceObjectAtIndex:0 withObject:item];
                        sectionItem.items = [items mutableCopy];
                        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:self.selectedIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
                    }
                }];
                [self.navigationController pushViewController:fbVC animated:YES];
                break;
            }
            case SCDevicePatrolStatusProcessed: {
                [self showPatrolDetailVC:cellItem];
                break;
            }
            case SCDevicePatrolStatusUpload: {
                [SVProgressHUD showErrorWithStatus:@"设备已巡检，请尽快上传巡检信息" duration:1.0 dismiss:nil];
            } break;
            default:
                break;
        }
    } else {
       [self push2DeviceSelectVC:SCDevicePatrolTypeQRCode];
    }
}

// 跳转到已巡检详情页
- (void)showPatrolDetailVC:(SCDevicePatrolCellDBItem *)item {
    SCDevicePatrolDetailViewController *detailVC = [[SCDevicePatrolDetailViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolDetailViewController class]) bundle:nil];
    [detailVC setUpWithCellItem:item];
    [self.navigationController pushViewController:detailVC animated:YES];
}


@end
