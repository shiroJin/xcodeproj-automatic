//
//  SCOtherBorrowViewController.m
//  Butler
//
//  Created by guanhongxiang on 2019/4/3.
//  Copyright © 2019 UAMA Inc. All rights reserved.
//

#import "SCOtherBorrowViewController.h"
#import "SCDatePicerViewController.h"
#import "SCItemsBorrowingActionViewController.h"

#import "SCButton.h"
#import "SCTableFooterView.h"
#import "SCCommonTextFieldTableCell.h"
#import "SCCommonContentCell.h"
#import "SCGoodsBorrowGiveBackDoneCell.h"
#import "SCHistoryTagCustomView.h"
#import "SCGoodsBorrowVerifyCodeView.h"
#import "SCCustomTextViewCell.h"

#import "CalendarHelper.h"
#import "SCGoodsBorrowingItem.h"

#import "SCGoodsBorrowOtherSendCodeAPI.h"
#import "SCGoodsBorrowLendCommitAPI.h"
static NSInteger const kCompanyTextViewTag = 2;
NSString * const kGoodsBorrowCompanyHistoryListKey = @"GoodsBorrowCompanyHistoryListKey";

@interface SCOtherBorrowViewController ()<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
//基本内容
@property (strong, nonatomic) NSArray *contentArray;

// 确认提交按钮
@property (strong, nonatomic) SCButton *submitButton;
@property (strong, nonatomic) SCTableFooterView *footerView;

//公司名称
@property (strong, nonatomic) NSString *companyName;
@property (copy, nonatomic) NSString *phone;
@property (copy, nonatomic) NSString *userName;

@property (strong, nonatomic) SCDatePicerViewController *datePickerVC;
///预计归还事时间
@property (strong, nonatomic) NSString *planGiveBackTimeStr;

/// 选中的物品数组
@property (strong, nonatomic) NSMutableArray *borrowGoodsArray;

@property (strong, nonatomic) SCHistoryTagCustomView *tagView;

@property (strong, nonatomic) NSMutableArray *historyCompanyList;

/// 验证码view
@property (strong, nonatomic) SCGoodsBorrowVerifyCodeView *verifyCodeView;
/// 验证码
@property (strong, nonatomic) NSString *verifyCode;
@end

@implementation SCOtherBorrowViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupData];
    [self setupView];
    self.title = @"他人借用";
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.verifyCodeView removeFromSuperview];
}

- (void)setupView
{
    //确认按钮
    self.footerView = [[SCTableFooterView alloc] initWithButtonItems:self.submitButton, nil];
    self.tableView.tableFooterView = self.footerView;
    //tableview
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.view.backgroundColor = SC_BACKGROUD_COLOR;
    [self.tableView registerCellWithCellName:[SCCommonTextFieldTableCell sc_className]];
    [self.tableView registerCellWithCellName:[SCCommonContentCell sc_className]];
    [self.tableView registerCellWithCellName:[SCGoodsBorrowGiveBackDoneCell sc_className]];
    [self.tableView registerCellWithCellName:[SCCustomTextViewCell sc_className]];
    // 给tableview添加空白点击事件
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewTap:)];
    tap.delegate = self;
    [self.tableView addGestureRecognizer:tap];
}

- (void)setupData
{
    self.contentArray = @[@{@"title":@"姓名：",@"placeholder":@"请输入借用人姓名"},@{@"title":@"手机号：",@"placeholder":@"请输入借用手机号"},@{@"title":@"单位名称：",@"placeholder":@"请输入借单位名称"},@{@"title":@"借出物品：",@"placeholder":@"请选择借出物品"},@{@"title":@"预计归还时间：",@"placeholder":@"请选择预计归还时间"}];
    
    self.historyCompanyList = [[[NSUserDefaults standardUserDefaults] valueForKey:kGoodsBorrowCompanyHistoryListKey] mutableCopy];
    if (!self.historyCompanyList) {
        self.historyCompanyList = [NSMutableArray array];
    }
}


#pragma mark - UITableViewDelegate && UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 5;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 3) {
        return self.borrowGoodsArray.count + 1;
    } else {
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section > 2) {
        if (indexPath.row > 0) {
            SCGoodsBorrowGiveBackDoneCell *cell = [tableView dequeueCellName:[SCGoodsBorrowGiveBackDoneCell sc_className] indexPath:indexPath];
            [cell loadData:self.borrowGoodsArray[indexPath.row - 1]];
            cell.separatorInset = UIEdgeInsetsMake(0, SCREEN_WIDTH, 0, 0);
            [cell showSeparateView:(indexPath.row != self.borrowGoodsArray.count)];
            cell.numLabel.textColor = SC_TEXT_THEME_COLOR;
            return cell;
        }
        SCCommonContentCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCCommonContentCell sc_className] forIndexPath:indexPath];
        [self configContentCell:cell indexPath:indexPath];
        return cell;
    } else {
        if (indexPath.section == 2) {
            SCCustomTextViewCell *cell = [tableView dequeueCellName:[SCCustomTextViewCell sc_className] indexPath:indexPath];
            [self configTextViewCell:cell indexPath:indexPath];
            return cell;
        } else {
            SCCommonTextFieldTableCell *cell = [tableView dequeueCellName:[SCCommonTextFieldTableCell sc_className] indexPath:indexPath];
            
            [self congfigTextFieldCell:cell indexPath:indexPath];
            return cell;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2) {
        return UITableViewAutomaticDimension;
    }
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section > 2) {
        return 8.f;
    } else {
        return CGFLOAT_MIN;
    }
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self dismissHistoryTag];
    if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            // 选择借出物品
            [self actionForChooseGoods];
        }
    } else if (indexPath.section == 4){
        //预计归还时间
        [self actionForTime];
    }
}

/// 填充TextField的cell
- (void)configTextViewCell:(SCCustomTextViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    
    NSString *title = self.contentArray[indexPath.section][@"title"];
    NSString *text = self.companyName;
    NSString *placeholder = @"请输入单位名称";
    
    [cell.textView setValue:@20 forKey:PROPERTY_NAME];
    [cell.textView  setValue:@"单位名称不能超过20字" forKey:PROPERTY_ERRORMSG];
    cell.textView.tag = kCompanyTextViewTag;
    cell.tableView = self.tableView;
    cell.textView.placeholder = placeholder;
    cell.textView.font = [UIFont systemFontOfSize:15.f];
    cell.textView.returnKeyType = UIReturnKeyDone;
    [cell refreshCellWithTitle:title text:text];
    
    @weakify(self);
    cell.textViewShouldBegin = ^{
        @strongify(self);
        [self showHistoryTag];
    };
    
    cell.textViewDidEndEditing = ^{
        @strongify(self);
        [self dismissHistoryTag];
    };
    cell.textViewBlock = ^(NSString *text) {
        @strongify(self);
        self.companyName = text;
    };
    
    cell.textViewHeightChange = ^(CGFloat value){
        @strongify(self);
        if ([self.tableView.subviews containsObject:self.tagView]) {
            [UIView animateWithDuration:0.3 animations:^{
                self.tagView.top += value;
            }];
        }
    };
}

// 设置内容cell
- (void)configContentCell:(SCCommonContentCell *)cell indexPath:(NSIndexPath *)indexPath
{
    NSString *title = self.contentArray[indexPath.section][@"title"];
    NSString *content = self.contentArray[indexPath.section][@"placeholder"];
    UIColor *contentColor = SC_TEXT_GRAY_COLOR;
    BOOL showArrow = YES;
    if (indexPath.section == 3) {// 选物品
        if (indexPath.row == 0) {
            content = self.borrowGoodsArray.count ? @"" : content;
            contentColor = self.borrowGoodsArray.count ? SC_TEXT_THEME_COLOR : SC_TEXT_GRAY_COLOR;
            [cell setShowSeparatorLine:self.borrowGoodsArray.count];
            cell.leftMargin.constant =  30.f;
            
        }
    } else if (indexPath.section == 4){
        content = self.planGiveBackTimeStr.length ? self.planGiveBackTimeStr : content;
        contentColor = self.planGiveBackTimeStr.length > 0 ? SC_TEXT_THEME_COLOR : SC_TEXT_GRAY_COLOR;
    }
    cell.titleLabel.font = [UIFont systemFontOfSize:15.f];
    cell.contentLabel.font = [UIFont systemFontOfSize:15.f];
    cell.contentLabel.textColor = contentColor;
    [cell setUpCellWithTitle:title content:content showArraw:showArrow];
}

// 设置填入cell
- (void)congfigTextFieldCell:(SCCommonTextFieldTableCell *)cell indexPath:(NSIndexPath *)indexPath
{
    NSString *title = self.contentArray[indexPath.section][@"title"];
    NSString *content = self.contentArray[indexPath.section][@"placeholder"];
    cell.textField.returnKeyType = UIReturnKeyDone;
    if (indexPath.section == 0) {
        [cell.textField setValue:@10 forKey:PROPERTY_NAME];
        [cell.textField setValue:@"姓名不能超过10字" forKey:PROPERTY_ERRORMSG];
    } else if (indexPath.section == 1) {
        [cell.textField setValue:@11 forKey:PROPERTY_NAME];
        [cell.textField setValue:@"手机号不能超过11位" forKey:PROPERTY_ERRORMSG];
        cell.textField.pattern = kPhoneRegular;
        cell.textField.keyboardType = UIKeyboardTypeNumberPad;
    }
    cell.textField.delegate = self;
    cell.markLabel.text = title;
    cell.textField.placeholder = content;
    cell.textField.tag = indexPath.section;
    // 添加分割线
    UIView *lineView = [[UIView alloc] init];
    lineView.backgroundColor = HEXCOLOR(0xF0F2F2);
    [cell.contentView addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.bottom.mas_equalTo(cell);
        make.height.mas_equalTo(1);
    }];

}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 3 && indexPath.row > 0) {
        return  YES;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView endEditing:YES];
    [self dismissHistoryTag];
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
    /// 解决侧滑可以滑到左侧的问题
    config.performsFirstActionWithFullSwipe = YES;
    
    return config;
}


#pragma mark - action
- (void)actionForChooseGoods
{
    SCItemsBorrowingActionViewController *actionVc = [[SCItemsBorrowingActionViewController alloc] initWithNibName:[SCItemsBorrowingActionViewController sc_className] bundle:nil];
    actionVc.selectGoods = self.borrowGoodsArray;
    @weakify(actionVc);
    actionVc.selectBtnClick = ^(NSMutableArray * _Nonnull selectItems) {
        @strongify(actionVc);
        self.borrowGoodsArray = [selectItems mutableCopy];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationAutomatic];
        [actionVc.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:actionVc animated:YES];
}

- (void)actionForShowDelete:(NSIndexPath *)indexPath
{
    [self.borrowGoodsArray removeObjectAtIndex:(indexPath.row - 1)];
    if (self.borrowGoodsArray.count) {
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
    } else {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)actionForTime
{
    [self.tableView endEditing:YES];
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


- (void)tableViewTap:(UIGestureRecognizer *)tap
{
    [self.tableView endEditing:YES];
    [self dismissHistoryTag];
}

- (void)submitButtonAction
{
    [self.tableView endEditing:YES];
    [self dismissHistoryTag];
  
    //赋值
    [self assignmentValue];
    //判断是否有值，并发起短信通知
    [self vaildValue];
    
}

- (void)vaildValue
{
    if (!self.userName.length) {
        [SVProgressHUD showErrorWithStatus:@"请输入借用人姓名" duration:1.5 dismiss:nil];
        return;
    }
    
    if (!self.phone.length) {
        [SVProgressHUD showErrorWithStatus:@"请输入借用人手机号码" duration:1.5 dismiss:nil];
        return;
    }
    if (!self.companyName.length) {
        [SVProgressHUD showErrorWithStatus:@"请输入单位名称" duration:1.5 dismiss:nil];
        return;
    }
    
    if (!self.borrowGoodsArray.count) {
        [SVProgressHUD showErrorWithStatus:@"请选择借出物品" duration:1.5 dismiss:nil];
        return;
    }
    
    if (!self.planGiveBackTimeStr) {
        [SVProgressHUD showErrorWithStatus:@"请选择预计归还时间" duration:1.5 dismiss:nil];
        return;
    }
    NSString *currentDate = [CalendarHelper convertStringFromDate:[NSDate date] type:@"yyyy-MM-dd HH:mm"];
    // 时间比较
    if ([CalendarHelper compareTime:currentDate withAnotherTime:self.planGiveBackTimeStr formatter:@"yyyy-MM-dd HH:mm"]  == 1) {
        [SVProgressHUD showErrorWithStatus:@"请修改预计归还时间" duration:1.5 dismiss:nil];
        return;
    }
    // 发送验证码
    [self sendVerifyCode];
}

- (void)assignmentValue
{
    SCCommonTextFieldTableCell *nameCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    self.userName = nameCell.textField.text;
    
    SCCommonTextFieldTableCell *phoneCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
    self.phone = phoneCell.textField.text;
    SCCustomTextViewCell *companyCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]];
    self.companyName = companyCell.textView.text;
}

- (void)sendVerifyCode
{
    SCGoodsBorrowOtherSendCodeAPI *api = [[SCGoodsBorrowOtherSendCodeAPI alloc] init];
    api.borrowArray = self.borrowGoodsArray;
    api.userMobile = self.phone;
    api.planReturnTime = self.planGiveBackTimeStr;
    [SVProgressHUD showInfoWithStatus:@"正在发送短信..." duration:1 dismiss:^{
        [api startWithCompletionWithSuccess:^(id responseDataDict) {
            [SVProgressHUD dismiss];
            // 显示借出码界面
            [self showVerifyCodeView];
            
        } failure:^(NSError *error) {
            [SCAlertHelper handleError:error];
        }];
    }];
}

// 提交订单
- (void)commitBorrow
{
    if (!self.verifyCode || self.verifyCode.length != 6) {
        [SVProgressHUD showErrorWithStatus:@"请输入6位借用码" duration:1.5 dismiss:nil];
        return;
    }
    [self dismissVerifyCodeView];
    SCGoodsBorrowLendCommitAPI *api = [[SCGoodsBorrowLendCommitAPI alloc] init];
    api.lendType = SCGoodsBorrowLendTypeOther;
    api.lendUserMobile = self.phone;
    api.lendUserCompany = self.companyName;
    api.commitArr = self.borrowGoodsArray;
    api.planReturnTime = self.planGiveBackTimeStr;
    api.verifyCode = self.verifyCode;
    api.userName = self.userName;
    [SVProgressHUD show];
    [api startWithCompletionWithSuccess:^(id responseDataDict) {
        // 处理新的值
        [self dealWithHistoryTag:self.companyName];
        [SVProgressHUD showSuccessWithStatus:@"借出成功" duration:1.5 dismiss:^{
            // 成功回调
            if (self.otherBorrowCommit) {
                self.otherBorrowCommit();
            }
            [self.navigationController popViewControllerAnimated:YES];
        }];
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
        [self showVerifyCodeView];
    }];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isKindOfClass:[UITableView class]]) {
        return YES;
    }
    return NO;
}

#pragma  mark --lazy method
- (SCButton *)submitButton {
    if (!_submitButton) {
        @weakify(self)
        _submitButton = [SCButton buttonWithTitle:@"确认提交" textColor:[UIColor whiteColor] backColor:SC_TEXT_GREEN_COLOR action:^(id sender) {
            @strongify(self)
            [self submitButtonAction];
        }];
    }
    return _submitButton;
}

- (SCHistoryTagCustomView *)tagView
{
    if (!_tagView) {
        _tagView = [[SCHistoryTagCustomView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY([self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]].frame), SCREEN_WIDTH, 0) collectionViewLayout:[UICollectionViewLayout new]];
        @weakify(self);
        _tagView.deleteHistory = ^{
            @strongify(self);
            if (self.historyCompanyList) {
                [self.historyCompanyList removeAllObjects];
                [self dismissHistoryTag];
                [self dealWithHistoryTag:nil];
            }
        };
        _tagView.selectItemBlock = ^(NSInteger index) {
            @strongify(self);
            SCCustomTextViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]];
            [cell setTextStr:self.historyCompanyList[index]];
            [self.tableView endEditing:YES];
            [self dismissHistoryTag];
        };
    }
    return _tagView;
}



#pragma mark -showTagView

- (void)showHistoryTag
{
    if (self.historyCompanyList.count) {
        [self.tagView setHistoryList:self.historyCompanyList];
        CGFloat height;
        if (self.tagView.collectionViewLayout.collectionViewContentSize.height > 150) {
            height = 150;
        } else {
            height = self.tagView.collectionViewLayout.collectionViewContentSize.height;
        }
        [self.tableView addSubview:self.tagView];
        [UIView animateWithDuration:0.3f animations:^{
            self.tagView.height = height;
        } completion:^(BOOL finished) {
            
        }];
    }
}

- (void)dismissHistoryTag
{
    if ([self.tableView.subviews containsObject:self.tagView]) {
        [UIView animateWithDuration:0.3f animations:^{
            self.tagView.height = 0.f;
        } completion:^(BOOL finished) {
            [self.tagView dismiss];
        }];
    }
}


- (void)dealWithHistoryTag:(NSString *)newTag
{
    if (newTag && newTag.length) {
        // 判断是否存在
        NSString *historyExistTag;
        for (NSString *historyTag in self.historyCompanyList) {
            if ([newTag isEqualToString:historyTag]) {
                historyExistTag = historyTag;
                break;
            }
        }
        if (historyExistTag) {
            // 移除存在的
            [self.historyCompanyList removeObjectAtIndex:[self.historyCompanyList indexOfObject:historyExistTag]];
        } else {
            if (self.historyCompanyList.count >= 10) {
                //移除最后一个
                [self.historyCompanyList removeObjectsInRange:NSMakeRange(9, self.historyCompanyList.count - 9)];
            }
        }
        // 添加到第一个
        [self.historyCompanyList insertObject:newTag atIndex:0];
    }
    [[NSUserDefaults standardUserDefaults] setValue:self.historyCompanyList forKey:kGoodsBorrowCompanyHistoryListKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark - SCGoodsBorrowVerifyCodeView
- (void)showVerifyCodeView
{
    if (![self.navigationController.view.subviews containsObject:self.verifyCodeView]) {
        self.verifyCodeView = [[NSBundle mainBundle] loadNibNamed:[SCGoodsBorrowVerifyCodeView sc_className] owner:self options:nil].firstObject;
        self.verifyCodeView.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
        @weakify(self);
        self.verifyCodeView.verifyCodeClick = ^(NSString * code) {
            @strongify(self);
            self.verifyCode = code;
            [self commitBorrow];
        };
        [self.navigationController.view insertSubview:self.verifyCodeView aboveSubview:self.view];
    }
    
}

- (void)dismissVerifyCodeView
{
    if ([self.navigationController.view.subviews containsObject:self.verifyCodeView]) {
        [self.verifyCodeView verifyCodeViewDismiss];
    }
}


@end
