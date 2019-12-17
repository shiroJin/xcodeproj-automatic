//
//  SCOwnerBorrowViewController.m
//  Butler
//
//  Created by guanhongxiang on 2019/4/3.
//  Copyright © 2019 UAMA Inc. All rights reserved.
//

#import "SCOwnerBorrowViewController.h"
#import "SCViewControllerPresenter.h"
#import "SCDatePicerViewController.h"
#import "SCCommonChooseController.h"
#import "SCItemsBorrowingActionViewController.h"
#import "SCGoodsBorrowViewContainer.h"

#import "SCButton.h"
#import "SCTableFooterView.h"
#import "SCCommonContentCell.h"
#import "SCGoodsBorrowGiveBackDoneCell.h"

#import "SCPropertyUserModel.h"
#import "SCUniversalCodeResult.h"
#import "SCGoodsBorrowingItem.h"
#import "UITableView+FDTemplateLayoutCell.h"

#import "SCPropertyGetUserAPI.h"
#import "SCGoodsBorrowLendCommitAPI.h"
#import "SCGoodsBorrowOrderDetaiAPI.h"
#import "SCGoodsBorrowOrderLendCommitAPI.h"

#import "CalendarHelper.h"

@interface SCOwnerBorrowViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
//基本内容
@property (strong, nonatomic) NSArray *contentArray;

// 确认提交按钮
@property (strong, nonatomic) SCButton *submitButton;
@property (strong, nonatomic) SCTableFooterView *footerView;

//房号和地址
@property (strong, nonatomic) NSString *roomId;
@property (strong, nonatomic) NSString *addressString;

/// 选择用户的数组；
@property (strong, nonatomic) NSMutableArray *inviterArray;
/// 业主名字
@property (strong, nonatomic) SCPropertyUserModel *inviterModel;
// 选中
@property (assign, nonatomic) NSInteger selectIndex;

@property (strong, nonatomic) SCDatePicerViewController *datePickerVC;
///预计归还事时间
@property (strong, nonatomic) NSString *planGiveBackTimeStr;

/// 选中的物品数组
@property (strong, nonatomic) NSMutableArray<SCGoodsBorrowingItem *> *borrowGoodsArray;
/// 订单借用数组
@property (strong, nonatomic) NSMutableArray<SCGoodsBorrowOrderGoods *> *orderBorrowGoodsArr;

@property (strong, nonatomic) SCGoodsBorrowListModel *detailModel;

@end

@implementation SCOwnerBorrowViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupData];
    [self setupView];
    self.title = [self isCanEdit] ? @"业主借用" : @"待借出物品";
}

- (void)setupView
{
    //确认按钮
    self.footerView = [[SCTableFooterView alloc] initWithButtonItems:self.submitButton, nil];
    self.tableView.tableFooterView = self.footerView;
    //tableview
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.view.backgroundColor = SC_BACKGROUD_COLOR;
    [self.tableView registerCellWithCellName:[SCCommonContentCell sc_className]];
    [self.tableView registerCellWithCellName:[SCGoodsBorrowGiveBackDoneCell sc_className]];
}

- (void)setupData
{
    if (self.isFromScanOwnerCode) {
        //扫描进来，业主订单二维码
        self.detailModel = self.qrcodeDetail;
    }
    self.contentArray = @[@{@"title":@"房号：",@"placeholder":@"请选择借用人房号"},@{@"title":@"姓名：",@"placeholder":@"请选择借用人姓名"},@{@"title":@"借出物品：",@"placeholder":@"请选择借出物品"},@{@"title":@"预计归还时间：",@"placeholder":@"请选择预计归还时间"}];
    
    if (self.orderId) {
        [self fetchDetail];
    }
    
    if (self.result) {
        self.addressString = self.result.roomAddress;
        self.roomId = self.result.roomId;
        self.inviterModel = [[SCPropertyUserModel alloc] init];
        self.inviterModel.userName = self.result.userName;
        self.inviterModel.userId = self.result.userId;
    }
    
}

- (void)fetchDetail
{
    [SVProgressHUD show];
    SCGoodsBorrowOrderDetaiAPI *api = [[SCGoodsBorrowOrderDetaiAPI alloc] init];
    api.orderId = self.orderId;
    [api startWithCompletionWithSuccess:^(id responseDataDict) {
        [SVProgressHUD dismiss];
        SCGoodsBorrowListModel *model = [SCGoodsBorrowListModel mj_objectWithKeyValues:responseDataDict];
        self.detailModel = model;
        [self.tableView reloadData];
    } failure:^(NSError *error) {
        [SVProgressHUD dismiss];
        [SCAlertHelper handleError:error];
    }];
    
}

- (void)setDetailModel:(SCGoodsBorrowListModel *)detailModel
{
    _detailModel = detailModel;
    self.addressString = _detailModel.lendUserRoomAddress;
    self.inviterModel = [[SCPropertyUserModel alloc] init];
    self.inviterModel.userName = _detailModel.lendUserName;
    self.orderBorrowGoodsArr = _detailModel.orderGoodsList;
    self.planGiveBackTimeStr = _detailModel.planReturnTime;
}

#pragma mark - UITableViewDelegate && UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 2) {
        if ([self isCanEdit]) {
            return self.borrowGoodsArray.count + 1;
        } else {
            return self.orderBorrowGoodsArr.count + 1;
        }
    } else {
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2) {
        if (indexPath.row > 0) {
            SCGoodsBorrowGiveBackDoneCell *cell = [tableView dequeueCellName:[SCGoodsBorrowGiveBackDoneCell sc_className] indexPath:indexPath];
            if ([self isCanEdit]) {
                [cell loadData:self.borrowGoodsArray[indexPath.row - 1]];
            } else {
                [cell loadData:self.orderBorrowGoodsArr[indexPath.row - 1]];
            }
            NSInteger lastIndex = [self isCanEdit] ? self.borrowGoodsArray.count : self.orderBorrowGoodsArr.count;
            [cell showSeparateView:(indexPath.row != lastIndex)];
            cell.numLabel.textColor = SC_TEXT_THEME_COLOR;
            return cell;
        }
    }
    SCCommonContentCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCCommonContentCell sc_className] forIndexPath:indexPath];
    [self configCell:cell indexPath:indexPath];
    return cell;
}
- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2) {
        if (indexPath.row > 0) {
            return UITableViewAutomaticDimension;
        }
    }
    if (indexPath.section == 0) {
        return [tableView fd_heightForCellWithIdentifier:[SCCommonContentCell sc_className] configuration:^(id cell) {
            [self configCell:cell indexPath:indexPath];
        }];
    }
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section >= 2) {
        return 8.f;
    } else {
        return CGFLOAT_MIN;
    }
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        if (![self isCanEdit]) {
            return;
        }
        //跳转到选择地址
        [self actionForAddress];
    } else if (indexPath.section == 1){
        if (![self isCanEdit]) {
            return;
        }
        //选择x姓名
        [self requestForInviterlist];
        
    } else if (indexPath.section == 2) {
        if (![self isCanEdit]) {
            return;
        }
        if (indexPath.row == 0) {
            // 选择借出物品
            [self actionForChooseGoods];
        }
    } else {
        //预计归还时间
        [self actionForTime];
    }
}

- (void)configCell:(SCCommonContentCell *)cell indexPath:(NSIndexPath *)indexPath
{
    NSString *title = self.contentArray[indexPath.section][@"title"];
    NSString *content = self.contentArray[indexPath.section][@"placeholder"];
    UIColor *contentColor = SC_TEXT_GRAY_COLOR;
    BOOL showArrow = YES;
    switch (indexPath.section) {
        case 0:
            content = self.addressString.length ? self.addressString : content;
            contentColor = self.addressString.length > 0 ? SC_TEXT_THEME_COLOR : SC_TEXT_GRAY_COLOR;
            showArrow = [self isCanEdit];
            cell.leftMargin.constant = [self isCanEdit] ? 30.f : 15.f;
            break;
        case 1:
            content = self.inviterModel ? self.inviterModel.userName : content;
            contentColor = self.inviterModel ? SC_TEXT_THEME_COLOR : SC_TEXT_GRAY_COLOR;
            showArrow = [self isCanEdit];
            cell.leftMargin.constant = [self isCanEdit] ? 30.f : 15.f;
            cell.topLineView.hidden = NO;
            cell.topLineLeftMargin.constant = 0.f;
            cell.topLineRightMargin.constant = 0.f;
            break;
        case 2:
        {
            BOOL isHaveContent = [self isCanEdit] ? self.borrowGoodsArray.count : self.orderBorrowGoodsArr.count;
            if (indexPath.row == 0) {
                content = isHaveContent ? @"" : content;
                contentColor = isHaveContent ? SC_TEXT_THEME_COLOR : SC_TEXT_GRAY_COLOR;
                [cell setShowSeparatorLine:YES];
                showArrow = [self isCanEdit];
                cell.leftMargin.constant = [self isCanEdit] ? 30.f : 15.f;
                
            }
        }
            break;
            
        case 3:
            content = self.planGiveBackTimeStr.length ? self.planGiveBackTimeStr : content;
            contentColor = self.planGiveBackTimeStr.length > 0 ? SC_TEXT_THEME_COLOR : SC_TEXT_GRAY_COLOR;
            showArrow = YES;
            break;
        default:
            
            break;
    }
    cell.titleLabel.font = [UIFont systemFontOfSize:15.f];
    cell.contentLabel.font = [UIFont systemFontOfSize:15.f];
    cell.contentLabel.textColor = contentColor;
    [cell setUpCellWithTitle:title content:content showArraw:showArrow];
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 2 && indexPath.row > 0 && [self isCanEdit]) {
        return  YES;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

// 添加自定义的侧滑功能
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 添加一个删除按钮
    
    @weakify(self);
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"删除" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
        @strongify(self);
        [self actionForShowDelete:indexPath];
    }];
    deleteAction.backgroundColor = HEXCOLOR(0xFF6648);
    return @[deleteAction];
}


- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath  API_AVAILABLE(ios(11.0)){
    
    @weakify(self);
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        @strongify(self);
        [self actionForShowDelete:indexPath];
        completionHandler(YES);
    }];
    
    deleteAction.image = [UIImage imageNamed:@"delete_white"];
    deleteAction.backgroundColor = HEXCOLOR(0xFF6648);
    
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    /// 一直左滑可以直接使用第一个action
    config.performsFirstActionWithFullSwipe = YES;
    
    return config;
}


- (BOOL)isCanEdit{
    // 只要是有orderId或者是从扫业主订单二维码过来的，不可编辑，不可修改
    if (self.orderId || self.isFromScanOwnerCode) {
        return NO;
    }
    return YES;
}


#pragma mark --action
- (void)actionForAddress
{
    @weakify(self)
    [SCViewControllerPresenter presentBuildingVCWithFinish:^(SCAddress *address) {
        @strongify(self)
        if (self.roomId.length > 0 && ![ISNULL(address.roomId) isEqualToString:ISNULL(self.roomId)]) {
            /// 这代表和之前的房号地址不一样，需要清除之前选择的业主
            self.inviterModel = nil;
            [self.inviterArray removeAllObjects];
        }
        
        self.addressString = address.description;
        self.roomId = address.roomId;
        [self.tableView reloadData];
    } cancel:^{
    } inVC:self];
}

- (void)actionForChooseInviter
{
    
    NSMutableArray *titleArray = [[NSMutableArray alloc] initWithCapacity:0];
    if (self.inviterArray.count > 0) {
        [self.inviterArray enumerateObjectsUsingBlock:^(SCPropertyUserModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            /// 获取title数组
            [titleArray addObject:ISNULL(obj.userName)];
            if ([obj.userId isEqualToString:self.inviterModel.userId]) {
                self.selectIndex = idx;
            }
        }];
    }

    if (titleArray.count == 0) {
        /// 没有数据
        [SVProgressHUD showErrorWithStatus:@"暂未获取到业主数据" duration:1.5 dismiss:nil];
        return;
    }
    
    SCCommonChooseController *vc = [[SCCommonChooseController alloc] initWithNibName:NSStringFromClass([SCCommonChooseController class]) bundle:nil];
    vc.title = @"选择人员";
    if (self.inviterModel.userId) {
        //如果invitemodel有值
        vc.lastIndex = self.selectIndex;
    }
    vc.titleArray = titleArray;
    @weakify(self);
    vc.selectBlock = ^(NSInteger index) {
        @strongify(self);
        self.selectIndex = index;
        self.inviterModel = self.inviterArray[index];
        [self.tableView reloadData];
    };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)actionForChooseGoods
{
    SCItemsBorrowingActionViewController *actionVc = [[SCItemsBorrowingActionViewController alloc] initWithNibName:[SCItemsBorrowingActionViewController sc_className] bundle:nil];
    actionVc.selectGoods = self.borrowGoodsArray;
    @weakify(actionVc);
    actionVc.selectBtnClick = ^(NSMutableArray * _Nonnull selectItems) {
        @strongify(actionVc);
        self.borrowGoodsArray = [selectItems mutableCopy];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationAutomatic];
        [actionVc.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:actionVc animated:YES];
}

//删除操作
- (void)actionForShowDelete:(NSIndexPath *)indexPath
{
    [self.borrowGoodsArray removeObjectAtIndex:(indexPath.row - 1)];
    if (self.borrowGoodsArray.count) {
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
    } else {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}


- (void)actionForTime
{
    @weakify(self)
    if (!_datePickerVC) {
        _datePickerVC = [[SCDatePicerViewController alloc] initWithNibName:[SCDatePicerViewController sc_className] bundle:nil];
        _datePickerVC.datePickerMode = UIDatePickerModeDateAndTime;
        _datePickerVC.title = @"请选择预计归还时间";
        _datePickerVC.confirmButtonTitle = @"确定";
    }
    // 30天 + 半小时(最小时间也往前推了半小时)
    _datePickerVC.maximumDate = [NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 30)];
    _datePickerVC.minimumDate = [NSDate date];
//    _datePickerVC.minuteInterval = 30;
    if (self.planGiveBackTimeStr.length > 0) {
        _datePickerVC.curDate = [CalendarHelper getDateFromString:self.planGiveBackTimeStr withFormatter:@"yyyy-MM-dd HH:mm"];
    } else {
        _datePickerVC.curDate = [NSDate date];
    }
    [_datePickerVC choseDateFinishBlock:^(ButtonType btnType, NSDate *date) {
        @strongify(self)
        if (btnType == ButtonTypeOK) {
            self.planGiveBackTimeStr = [CalendarHelper convertStringFromDate:date type:@"yyyy-MM-dd HH:mm"];
            [self.tableView reloadData];
        }
        [self dismissPopupViewControllerWithanimationType:MJPopupViewAnimationFade];
    }];
    [self presentPopupViewController:_datePickerVC animationType:MJPopupViewAnimationFade];
}


#pragma mark --api
/// 根据房号获取业主列表数据
- (void)requestForInviterlist {
    
    if (self.roomId.length == 0) {
        [SVProgressHUD showErrorWithStatus:@"请先选择房号" duration:1.5 dismiss:^{}];
        return;
    }
    
    SCPropertyGetUserAPI *api = [[SCPropertyGetUserAPI alloc] init];
    [SVProgressHUD show];
    api.roomId = self.roomId;
    @weakify(self);
    [api startWithCompletionWithSuccess:^(id responseDataDict) {
        @strongify(self);
        [SVProgressHUD dismiss];
        NSMutableArray *tempList = [NSMutableArray array];
        if ([responseDataDict isKindOfClass:[NSArray class]]) {
            tempList = [SCPropertyUserModel mj_objectArrayWithKeyValuesArray:responseDataDict];
        }
        self.inviterArray = tempList;
        [self actionForChooseInviter];
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
    }];
}


- (void)submitButtonAction
{
    [self.tableView setEditing:NO animated:YES];
    if (!self.addressString.length) {
        [SVProgressHUD showErrorWithStatus:@"请选择房号" duration:1.5 dismiss:nil];
        return;
    }
    if (!self.inviterModel.userName.length) {
        [SVProgressHUD showErrorWithStatus:@"请选择借用人员" duration:1.5 dismiss:nil];
        return;
    }
    
    if (!self.planGiveBackTimeStr) {
        [SVProgressHUD showErrorWithStatus:@"请选择预计归还时间" duration:1.5 dismiss:nil];
        return;
    }
    // 时间比较
    NSString *currentDate = [CalendarHelper convertStringFromDate:[NSDate date] type:@"yyyy-MM-dd HH:mm"];
    // 时间比较
    if ([CalendarHelper compareTime:currentDate withAnotherTime:self.planGiveBackTimeStr formatter:@"yyyy-MM-dd HH:mm"]  == 1) {
        [SVProgressHUD showErrorWithStatus:@"请修改预计归还时间" duration:1.5 dismiss:nil];
        return;
    }
    
    NSMutableArray *commitArray = [NSMutableArray array];
    for (SCGoodsBorrowingItem *good in self.borrowGoodsArray) {
        if (good.num) {
            [commitArray addObject:good];
        }
    }
    if ([self isCanEdit]) {
        if (!commitArray.count) {
            [SVProgressHUD showErrorWithStatus:@"请选择借出物品" duration:1.5 dismiss:nil];
            return;
        }
        // 如果可编辑订单
        [self commit:commitArray];
    } else {
        ///下单
        if (!self.orderBorrowGoodsArr.count) {
            [SVProgressHUD showErrorWithStatus:@"请选择借出物品" duration:1.5 dismiss:nil];
            return;
        }
        [self orderCommit];
    }
}

- (void)commit:(NSMutableArray *)commitArr
{
    SCGoodsBorrowLendCommitAPI *api = [[SCGoodsBorrowLendCommitAPI alloc] init];
    api.lendType = SCGoodsBorrowLendTypeOwner;
    api.commitArr = self.borrowGoodsArray;
    api.user = self.inviterModel;
    api.roomId = self.roomId;
    api.planReturnTime = self.planGiveBackTimeStr;
    api.userToken = self.result.userToken;
    [SVProgressHUD show];
    [api startWithCompletionWithSuccess:^(id responseDataDict) {
        [SVProgressHUD showSuccessWithStatus:@"借出成功" duration:1.5 dismiss:^{
            SCGoodsBorrowViewContainer *controller;
            for (UIViewController *vc in self.navigationController.childViewControllers) {
                if ([vc isKindOfClass:[SCGoodsBorrowViewContainer class]]) {
                    controller = (SCGoodsBorrowViewContainer *)vc;
                    break;
                }
            }
            if (controller) {
                // 刷新待归还
                [controller refreshViewAtPage:1];
                [self.navigationController popToViewController:controller animated:YES];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
    }];
}


- (void)orderCommit
{
    [SVProgressHUD show];
    SCGoodsBorrowOrderLendCommitAPI *api = [[SCGoodsBorrowOrderLendCommitAPI alloc] init];
    api.orderId = self.detailModel.orderId;
    api.planGiveBackStr = self.planGiveBackTimeStr;
    api.userToken = self.userToken;
    [api startWithCompletionWithSuccess:^(id responseDataDict) {
        [SVProgressHUD showSuccessWithStatus:@"借出成功" duration:1.5 dismiss:^{
            if (self.lendSuccess) {
                self.lendSuccess();
            }
            [self.navigationController popViewControllerAnimated:YES];
        }];
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
    }];
}

#pragma  mark --lazy method
- (SCButton *)submitButton {
    if (!_submitButton) {
        @weakify(self)
        _submitButton = [SCButton buttonWithTitle:@"确认借出" textColor:[UIColor whiteColor] backColor:SC_TEXT_GREEN_COLOR action:^(id sender) {
            @strongify(self)
            [self submitButtonAction];
        }];
    }
    return _submitButton;
}


@end
