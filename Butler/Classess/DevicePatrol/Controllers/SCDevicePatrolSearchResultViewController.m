//
//  SCDevicePatrolSearchResultViewController.m
//  Butler
//
//  Created by xujunhao on 16/7/27.
//  Copyright © 2016年 UAMA Inc. All rights reserved.
//

#import "SCDevicePatrolSearchResultViewController.h"
#import "SCDevicePatrolDetailViewController.h"
#import "SCDevicePatrolSelectViewController.h"
#import "SCDevicePatrolFBViewController.h"
#import "UITableView+FDTemplateLayoutCell.h"
#import "SCQRScanViewController.h"
#import "SCBLECentralManager.h"
#import "SCDevicePatrolViewCell.h"
#import "SCDevicePatrolGroupHeaderViewCell.h"
#import "SCDevicePatrolSectionDBItem.h"
#import "SCDevicePatrolCellDBItem.h"
#import "SCBeaconManager.h"
#import "SCDevicePatrolManager.h"
#import "SCFilterSearchBar.h"
#import "SCSelectExecutorViewController.h"

@interface SCDevicePatrolSearchResultViewController () <UITableViewDelegate, UITableViewDataSource>

// 搜索框
@property (strong, nonatomic) SCFilterSearchBar *searchView;
@property (nonatomic, strong) UITableView *tableView;
// SCDevicePatrolSectionItem数组
@property (strong, nonatomic) NSMutableArray *items;
@property (strong, nonatomic) SCDevicePatrolManager *patrolManager;
// 被巡检组
@property (assign, nonatomic) NSInteger selectedIndex;
// 被选择的QRCode
@property (strong, nonatomic) NSString *selQRCode;

@property (assign, nonatomic) NSInteger timeType;
///底部bgview
@property (strong, nonatomic) UIView *bgView;
///分配按钮
@property (strong, nonatomic) UIButton *distributeTaskBtn;
///选择执行人view
@property (strong, nonatomic) UIView *selectOperateView;
///选择执行人按钮
@property (strong, nonatomic) UIButton *selectOperateBtn;
///已选个数label
@property (strong, nonatomic) UILabel *selectedNumLabel;
/// 全选按钮
@property (strong, nonatomic) UIButton *allSelectBtn;
// 返回的时候是否需要更新数据
@property (assign, nonatomic) BOOL isUpdateData;

@property (assign, nonatomic) BOOL beginDistribute;

@property (strong, nonatomic) NSMutableArray *distributeTaskArray;

@property (assign, nonatomic) SCDevicePatrolSearch searchType;
/// 搜索的类型的数组
@property (nonatomic, strong) NSArray *marks;

@property (copy, nonatomic) NSString *searchString;

@end

@implementation SCDevicePatrolSearchResultViewController

- (SCDevicePatrolManager *)patrolManager {
    if (!_patrolManager) {
        _patrolManager = [[SCDevicePatrolManager alloc] init];
    }
    return _patrolManager;
}
- (UIView *)bgView
{
    if (!_bgView) {
        _bgView = [[UIView alloc] init];
    }
    return _bgView;
}

- (UIButton *)distributeTaskBtn
{
    if (!_distributeTaskBtn) {
        _distributeTaskBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_distributeTaskBtn setBackgroundColor:SC_TEXT_GREEN_COLOR];
        [_distributeTaskBtn setTitle:@"分配任务" forState:UIControlStateNormal];
        [_distributeTaskBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _distributeTaskBtn.titleLabel.font = [UIFont systemFontOfSize:18];
        [_distributeTaskBtn addTarget:self action:@selector(distributeTask:) forControlEvents:UIControlEventTouchUpInside];
        [_distributeTaskBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
        [_distributeTaskBtn setBackgroundImage:[UIImage createImageWithColor:[UIColor colorWithHexString:@"#AAAAAA"]] forState:UIControlStateDisabled];
    }
    return _distributeTaskBtn;
}

- (UIButton *)selectOperateBtn
{
    if (!_selectOperateBtn) {
        _selectOperateBtn = [[UIButton alloc] init];
        [_selectOperateBtn setBackgroundImage:[UIImage createImageWithColor:SC_APP_THEME_COLOR] forState:UIControlStateNormal];
        [_selectOperateBtn setTitle:@"选择执行人" forState:UIControlStateNormal];
        [_selectOperateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _selectOperateBtn.titleLabel.font = [UIFont systemFontOfSize:18];
        [_selectOperateBtn addTarget:self action:@selector(selectOperate:) forControlEvents:UIControlEventTouchUpInside];
        [_selectOperateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
        [_selectOperateBtn setBackgroundImage:[UIImage createImageWithColor:[UIColor colorWithHexString:@"#7FBCFF"]] forState:UIControlStateDisabled];
    }
    return _selectOperateBtn;
}

- (UILabel *)selectedNumLabel
{
    if (!_selectedNumLabel) {
        _selectedNumLabel = [[UILabel alloc] init];
        _selectedNumLabel.textColor = SC_TEXT_GRAY_COLOR;
        _selectedNumLabel.font = [UIFont systemFontOfSize:12.f];
        _selectedNumLabel.text = [NSString stringWithFormat:@"%lu个",self.distributeTaskArray.count];
        [_selectedNumLabel sizeToFit];
    }
    return _selectedNumLabel;
}

- (UIButton *)allSelectBtn
{
    if (!_allSelectBtn) {
        _allSelectBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 75, 49)];
        [_allSelectBtn setImage:[UIImage imageNamed:@"unchecked_icon_grey"] forState:UIControlStateNormal];
        [_allSelectBtn setImage:[UIImage imageNamed:@"checked_icon_blue"] forState:UIControlStateSelected];
        [_allSelectBtn setTitle:@"全选" forState:UIControlStateNormal];
        [_allSelectBtn setTitleColor:SC_TEXT_THEME_COLOR forState:UIControlStateNormal];
        [_allSelectBtn addTarget:self action:@selector(allSelecteAction:) forControlEvents:UIControlEventTouchUpInside];
        _allSelectBtn.titleLabel.font = [UIFont systemFontOfSize:15.f];
        _allSelectBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -5, 0, 0);
    }
    return _allSelectBtn;
}

- (UIView *)selectOperateView
{
    if (!_selectOperateView) {
        _selectOperateView = [[UIView alloc] init];
        _selectOperateView.backgroundColor = [UIColor whiteColor];
        //全选按钮
        [_selectOperateView addSubview:self.allSelectBtn];
        //选择执行人按钮
        [_selectOperateView addSubview:self.selectOperateBtn];
        [self.selectOperateBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.trailing.mas_equalTo(_selectOperateView);
            make.width.mas_equalTo(120.f);
        }];
        //数量number
        [_selectOperateView addSubview:self.selectedNumLabel];
        [self.selectedNumLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.trailing.mas_equalTo(self.selectOperateBtn.mas_leading).mas_offset(-15);
            make.centerY.mas_equalTo(_selectOperateView);
        }];
        
        UILabel *constLabel = [[UILabel alloc] init];
        [_selectOperateView addSubview:constLabel];
        [constLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.mas_equalTo(_selectOperateView);
            make.trailing.mas_equalTo(self.selectedNumLabel.mas_leading).mas_offset(-5);
        }];
        constLabel.text = @"已选：";
        constLabel.textColor = SC_TEXT_THEME_COLOR;
        constLabel.font = [UIFont systemFontOfSize:15.f];
        [constLabel sizeToFit];
    }
    return _selectOperateView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupView];
    [self setupData];
    [self setupNav];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.beginDistribute) {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)setupNav
{
    @weakify(self)
    UIBarButtonItem *item = [[UIBarButtonItem alloc] bk_initWithTitle:@"取消" style:UIBarButtonItemStyleDone handler:^(id sender) {
        @strongify(self)
        //取消
        [self cancel];
    }];
    self.title = @"选择任务";
    self.navigationItem.rightBarButtonItem = item;
}

- (void)setupView {
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    //searchbar
    [self setupSearchBar];
    //tableview
    [self setupTableView];
    // bottomView
    [self setupBottomView];
}

- (void)setupSearchBar
{
    /// 状态栏假背景
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, SCREEN_WIDTH, SCStatusBarHeight)];
    topView.backgroundColor = HEXCOLOR(0xD3D3D3);
    [self.view addSubview:topView];
    
    self.marks = self.canDistribute ? @[@"设施设备", @"执行人"] : @[@"设施设备"];
    self.searchType = SCDevicePatrolSearchDeviceName;
    
    _searchView = [SCFilterSearchBar loadNibView];
    _searchView.marks = self.marks;
    _searchView.placeholder = @"请输入巡检设备名称";
    _searchView.keyboardType = UIKeyboardTypeDefault;
    _searchView.showCancelButton = YES;
    self.searchView.showDescButton = NO;
    self.searchView.showScanButton = NO;
    _searchView.backColor = HEXCOLOR(0xD3D3D3);
    _searchView.point = CGPointMake(0.0f, SCFilterSearchBarHeight());
    _searchView.userPoint = YES;
    
    [self.view addSubview:_searchView];
    // 这里需要延迟弹出键盘，不然输入框输入字时会往下偏移
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.searchView becomeFirstResponder];
    });
    
    [_searchView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.mas_equalTo(0.0f);
        make.top.mas_equalTo(SCStatusBarHeight);
        make.height.mas_equalTo(44);
    }];
}

- (void)setupTableView
{
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_tableView registerCellWithCellName:@"SCDevicePatrolViewCell"];
    [_tableView registerCellWithCellName:@"SCDevicePatrolGroupHeaderViewCell"];
    _tableView.estimatedSectionFooterHeight = 0.0f;
    _tableView.estimatedSectionHeaderHeight = 0.0f;
    _tableView.estimatedRowHeight = 74.0f;
    [self.view addSubview:_tableView];
    
    [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.mas_equalTo(0);
        make.top.mas_equalTo(self.searchView.mas_bottom);
        if (@available(iOS 11.0,*)) {
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).mas_offset(self.canDistribute ? -49 : 0);
        } else {
            make.bottom.mas_equalTo(self.canDistribute ? -49 : 0);
        }
    }];
}

- (void)setupBottomView
{
    if (self.canDistribute) {
        
        [self.view addSubview:self.bgView];
        [self.bgView mas_makeConstraints:^(MASConstraintMaker *make) {
            if (@available(iOS 11.0,*)) {
                make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
            } else {
                make.bottom.mas_equalTo(0);
            }
            make.size.mas_equalTo(CGSizeMake(SCREEN_WIDTH, 49));
        }];
        [self.bgView addSubview:self.distributeTaskBtn];
        [self.distributeTaskBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(self.bgView);
        }];
        [self.bgView addSubview:self.selectOperateView];
        [self.selectOperateView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(self.bgView);
        }];
        self.selectOperateView.hidden = YES;
        self.distributeTaskBtn.enabled = NO;
    }
}

- (void)setupData {
    @weakify(self)
    // 取消搜索事件
    self.searchView.cancelAction = ^ {
        @strongify(self);
        [self.view endEditing:YES];
        [self dismissViewControllerAnimated:YES completion:^{
            if (self.isUpdateData)  {
                !self.itemChangedBlock?:self.itemChangedBlock();
            }
        }];
    };
    // 选择搜索类型
    self.searchView.itemSelect = ^(NSInteger index) {
        @strongify(self)
        [self showSelectSearchType:index];
    };
    // 键盘上点搜索按钮事件
    self.searchView.searchAction = ^ (NSString *text) {
        @strongify(self)
        if (ISNULL(text).length > 0) {
            self.searchString = text;
            [self.view endEditing:YES];
            [self loadItems:text];
        }
    };
    self.distributeTaskArray = [NSMutableArray array];
}

/// 显示当前选中的搜索类型
- (void)showSelectSearchType:(NSInteger)index {
    /// 切换的时候，一些搜索条件置空
    self.searchString = @"";
    
    NSString *title = self.marks[index];
    SCDevicePatrolSearch tempType = SCDevicePatrolSearchDeviceName;
    NSString *placeholder = @"";
    if ([title isEqualToString:@"设施设备"]) {
        placeholder = @"请输入巡检设备名称";
        tempType = SCDevicePatrolSearchDeviceName;
    } else if ([title isEqualToString:@"执行人"]) {
        placeholder = @"请输入执行人名称";
        tempType = SCDevicePatrolSearchExecutor;
    }
    self.searchView.placeholder = placeholder;
    self.searchView.text = nil;
    self.searchType = tempType;
}

- (void)reloadUI {
    if (self.items.count == 0) {
        [SCEmptyDataSetAssistant emptyForContentView:self.tableView builderBlock:^(SCEmptyDataSetBuilder *builder) {
            builder.emptyTitle = @"暂无巡检信息";
        } tappedBlock:^{ }];
        if (self.canDistribute) {
            self.distributeTaskBtn.enabled = NO;
        }
    } else {
        if (self.canDistribute) {
            self.distributeTaskBtn.enabled = YES;
        }
    }
    //刷新底部view
    [self reloadBottomView];
    [self.tableView reloadData];
}

- (void)reloadBottomView
{
    if (self.distributeTaskArray.count) {
        self.selectedNumLabel.textColor = SC_APP_THEME_COLOR;
    } else {
        self.selectedNumLabel.textColor = SC_TEXT_GRAY_COLOR;
    }
    self.selectOperateBtn.enabled = self.distributeTaskArray.count;
    self.allSelectBtn.selected = (self.distributeTaskArray.count == [self numberOfCellCountInDateSource]);
    self.selectedNumLabel.text = [NSString stringWithFormat:@"%lu个",self.distributeTaskArray.count];
}

- (NSInteger)numberOfCellCountInDateSource
{
    NSInteger num = 0;
    for (SCDevicePatrolSectionDBItem *item in self.items) {
        for (SCDevicePatrolCellDBItem *cellItem in item.items) {
            if (cellItem.patrolStatus == SCDevicePatrolStatusWaiting || cellItem.patrolStatus == SCDevicePatrolStatusExpire) {
                num += 1;
            }
        }
    }
    return num;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Public Method
- (void)setUpWithTimeType:(NSInteger)timeType {
    self.timeType = timeType;
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.items count];
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
        SCDevicePatrolGroupHeaderViewCell *cell = [tableView dequeueCellName:@"SCDevicePatrolGroupHeaderViewCell" indexPath:indexPath];
        [self configGroupHeaderCell:cell atIndexPath:indexPath];
        return cell;
    } else {
        SCDevicePatrolViewCell *cell = [tableView dequeueCellName:NSStringFromClass([SCDevicePatrolViewCell class]) indexPath:indexPath];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        [self configPatrolViewCell:cell atIndexPath:indexPath];
        return cell;
    }
    return [UITableViewCell new]; //fixed by 囧 以防崩溃;
}

#pragma mark - UITableViewDelegate Methods
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 8.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    CGFloat footerHeight = CGFLOAT_MIN;
    if (section == ([tableView numberOfSections] - 1)) {
        footerHeight = 8.0f;
    }
    return footerHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    if (row == 0) {
        return [tableView fd_heightForCellWithIdentifier:@"SCDevicePatrolGroupHeaderViewCell" cacheByIndexPath:indexPath configuration:^(SCDevicePatrolGroupHeaderViewCell *cell) {
                [self configGroupHeaderCell:cell atIndexPath:indexPath];
            }];
    } else {
        return SCDevicePatrolViewCellHeight;
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    if (row != 0) {
        if (section < _items.count) {
            SCDevicePatrolSectionDBItem *item = (SCDevicePatrolSectionDBItem *)self.items[section];
            SCDevicePatrolCellDBItem *cellItem = (SCDevicePatrolCellDBItem *)item.items[row-1];
            if (self.beginDistribute) {
                if (cellItem.patrolStatus == SCDevicePatrolStatusWaiting || cellItem.patrolStatus == SCDevicePatrolStatusExpire) {
                    cellItem.selected = !cellItem.selected;
                    if (cellItem.selected) {
                        [self.distributeTaskArray addObject:cellItem];
                    } else {
                        if ([self.distributeTaskArray containsObject:cellItem]) {
                            [self.distributeTaskArray removeObject:cellItem];
                        }
                    }
                    [self.tableView reloadData];
                    //刷新底部
                    [self reloadBottomView];
                }
            } else {
                if (cellItem.patrolStatus == SCDevicePatrolStatusProcessed) {
                    [self showPatrolDetailVC:cellItem];
                }
            }
        }
    }
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
    [cell setUpWithItem:cellItem];
    if (self.beginDistribute) {
        if (cellItem.patrolStatus == SCDevicePatrolStatusWaiting || cellItem.patrolStatus == SCDevicePatrolStatusExpire) {
            [cell setUserInteractionEnabled:YES];
        } else {
            [cell setUserInteractionEnabled:NO];
        }
    } else {
        if (cellItem.patrolStatus == SCDevicePatrolStatusProcessed) {
            [cell setUserInteractionEnabled:YES];
        } else {
            [cell setUserInteractionEnabled:NO];
        }
    }
}

#pragma mark - Private Methods
- (void)loadItems:(NSString *)deviceName {
    [SVProgressHUD show];
    [self.patrolManager fetchDevicePatrolListWithTimeType:self.timeType name:deviceName searchType:self.searchType success:^(NSArray<SCDevicePatrolSectionDBItem *> *items) {
        [SVProgressHUD dismiss];
        self.items = [items mutableCopy];
        [self reloadUI];
    } failureBlock:^(NSError *error) {
        [SVProgressHUD dismiss];
        [SCAlertHelper handleError:error];
        [self reloadUI];
    }];
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
            self.isUpdateData = YES;
            [self.items replaceObjectAtIndex:self.selectedIndex withObject:item];
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:self.selectedIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }];
    [self.navigationController pushViewController:selectVC animated:YES];
}

- (void)showBLEScanFailAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    @weakify(self)
    UIAlertAction *cancleAction = [UIAlertAction actionWithTitle:@"继续巡检" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self)
        [self push2DeviceSelectVC:SCDevicePatrolTypeNotBLE];
    }];
    if ([[UIDevice currentDevice].systemVersion floatValue] > 8.3) {
        [cancleAction setValue:HEXCOLOR(0x00AE08) forKey:@"titleTextColor"];
    }
    NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:@"找不到蓝牙点，可能是蓝牙出现了故障，请继续执行设备巡检" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17.0f], NSForegroundColorAttributeName:SC_TEXT_THEME_COLOR}];
    [alertController setValue:attributedMessage forKey:@"attributedMessage"];
    [alertController addAction:cancleAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

// 二维码处理
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
                [fbVC setUpWithCellItem:cellItem
                          inSectionItem:sectionItem
                                  chage:^(SCDevicePatrolCellDBItem *item) {
                                      @strongify(self)
                                      if (item) {
                                          self.isUpdateData = YES;
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

#pragma mark - Patrol Methods
// 开始蓝牙匹配
- (void)startBLEPatrolUsingUUID:(NSString *)UUID
                          major:(NSUInteger)major
                          minor:(NSUInteger)minor {
    if ([[SCBLECentralManager sharedInstance] BLEAvailableIn:self accessType:SCBLEAccessTypeDevicePatrol]) {
        if ([SCBeaconManager GPSAllwaysAuthorizedIn:self]) {
            @weakify(self)
            [SVProgressHUD showWithStatus:@"正在扫描蓝牙"];
            [[SCBeaconManager sharedInstance] scanBeaconUsingUUIDString:UUID major:major minor:minor success:^{
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

// 开始二维码匹配
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
        if ([[QRCode trim] length] > 9) {
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

- (void)showPatrolDetailVC:(SCDevicePatrolCellDBItem *)item {
    SCDevicePatrolDetailViewController *detailVC = [[SCDevicePatrolDetailViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolDetailViewController class]) bundle:nil];
    [detailVC setUpWithCellItem:item];
    [self.navigationController pushViewController:detailVC animated:YES];
}

#pragma mark - action

- (void)distributeTask:(UIButton *)sender
{
    self.beginDistribute = YES;
    [self.searchView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(-44);
    }];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.selectOperateView.hidden = NO;
//    self.selectOperateBtn.enabled = NO;
    if (self.timeType == 1) {
        for (SCDevicePatrolSectionDBItem *section in self.items) {
            section.patrolEnable = !self.beginDistribute;
        }
    }
    [self.tableView reloadData];
    [self reloadBottomView];
}

- (void)selectOperate:(UIButton *)sender
{
   //跳转去选择执行人
    SCSelectExecutorViewController *selectVc = [[SCSelectExecutorViewController alloc] initWithNibName:[SCSelectExecutorViewController sc_className] bundle:nil];
    selectVc.selectTaskIdArray = [[self.distributeTaskArray valueForKeyPath:@"patrolID"] copy];
    @weakify(self);
    selectVc.successBlock = ^ (SCSelectExecutor *executor){
        @strongify(self);
        if (self.timeType == 1) {
            for (SCDevicePatrolCellDBItem *cellItem in self.distributeTaskArray) {
                cellItem.executorId = executor.executorId;
                cellItem.executorUserName = executor.userName;
                cellItem.executorUserMobile = executor.mobileNum;
                [cellItem commit];
            }            
        }
        [self cancel];
        if (self.distributeBlock) {
            self.distributeBlock();
        }
        [self loadItems:self.searchString];
    };
    [self.navigationController pushViewController:selectVc animated:YES];
}

- (void)cancel
{
    self.beginDistribute = NO;
    self.selectOperateView.hidden = YES;
    //取消所有选中状态
    for (SCDevicePatrolCellDBItem *cellItem in self.distributeTaskArray) {
        cellItem.selected = NO;
    }
    [self.searchView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(SCStatusBarHeight);
    }];
    [self.distributeTaskArray removeAllObjects];
    if (self.timeType == 1) {
        for (SCDevicePatrolSectionDBItem *section in self.items) {
            section.patrolEnable = !self.beginDistribute;
        }
    }
    [self.tableView reloadData];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)allSelecteAction:(UIButton *)sender
{
    sender.selected = !sender.selected;
    //先移除
    [self.distributeTaskArray removeAllObjects];
    for (SCDevicePatrolSectionDBItem *item in self.items) {
        for (SCDevicePatrolCellDBItem *cellItem in item.items) {
            if (cellItem.patrolStatus == SCDevicePatrolStatusWaiting || cellItem.patrolStatus == SCDevicePatrolStatusExpire) {
                cellItem.selected = sender.isSelected;
                //再添加
                if (sender.isSelected) {
                    [self.distributeTaskArray addObject:cellItem];
                }
            }
        }
    }
    
    [self reloadUI];
}

@end
