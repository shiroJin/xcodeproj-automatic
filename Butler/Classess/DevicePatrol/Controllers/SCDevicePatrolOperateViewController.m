//
//  SCDevicePatrolOperateViewController.m
//  Butler
//
//  Created by abeihaha on 2017/1/4.
//  Copyright © 2017年 UAMA Inc. All rights reserved.
//

#import "SCDevicePatrolOperateViewController.h"

#import "SCDevicePatrolPanelViewCell.h"
#import "SCDevicePatrolCellDBItem.h"
#import "SCDevicePatrolSectionDBItem.h"
#import "SCDevicePatrolPanelItem.h"

#import "SZTextView.h"
#import "SCButton.h"
#import "SCTableFooterView.h"
#import "SCAddPhotoCollectionView.h"

#import "SCUploadItemManager.h"

#import "SCSavePhotoManager.h"
#import "SCBeaconManager.h"
#import "SCDevicePatrolUploadItem.h"
#import "SRKObject+SCHandler.h"

@interface SCDevicePatrolOperateViewController () <UITextViewDelegate, UITextFieldDelegate>

@property (copy, nonatomic) PatrolCellItemFinishBlock finish;
@property (strong, nonatomic) SCDevicePatrolCellDBItem *cellItem;
@property (strong, nonatomic) SCDevicePatrolSectionDBItem *sectionItem;

@property (strong, nonatomic) NSMutableArray *panelItems;//需抄表内容

@property (strong, nonatomic) NSString *remarkString;

@property (strong, nonatomic) SZTextView *remarkView;
@property (strong, nonatomic) SCAddPhotoCollectionView *photoView;
@property (strong, nonatomic) SCButton *submitButton;
@property (strong, nonatomic) SCButton *laterSubmitButton;
@property (strong, nonatomic) SCTableFooterView *footerView;

@property (strong, nonatomic) NSMutableArray *panelFields;

@end

@implementation SCDevicePatrolOperateViewController

- (SCAddPhotoCollectionView *)photoView {
    if (!_photoView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _photoView = [[SCAddPhotoCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _photoView.isEdit = NO;
    }
    return _photoView;
}

- (SZTextView *)remarkView {
    if (!_remarkView) {
        _remarkView = [[SZTextView alloc] init];
        _remarkView.placeholder = @"巡检结果：已完成巡检";
        _remarkView.delegate = self;
        _remarkView.font = [UIFont systemFontOfSize:14];
        _remarkView.textColor = SC_TEXT_THEME_COLOR;
        _remarkView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
        [_remarkView setValue:@(500) forKey:PROPERTY_NAME];
        [_remarkView setValue:@"内容最多输入500字" forKey:PROPERTY_ERRORMSG];
    }
    return _remarkView;
}

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

- (SCButton *)laterSubmitButton {
    if (!_laterSubmitButton) {
        @weakify(self)
        _laterSubmitButton = [SCButton buttonWithTitle:@"稍后上传" textColor:[UIColor whiteColor] backColor:SC_LATER_SUBMIT_BACK_COLOR action:^(id sender) {
            @strongify(self)
            [self laterSubmitButtonAction];
        }];
    }
    return _laterSubmitButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setUpUIContent];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Public Method

- (void)setUpWithPatrolCellItem:(SCDevicePatrolCellDBItem *)item
                  inSectionItem:(SCDevicePatrolSectionDBItem *)sectionItem
                         finish:(PatrolCellItemFinishBlock)finish {
    self.cellItem = item;
    if ([[item patrolPanelArray] count] > 0) {
        [self.panelItems addObjectsFromArray:[item patrolPanelArray]];
    }
    self.sectionItem = sectionItem;
    self.finish = finish;
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return _panelItems.count;
    return 1;
}

#pragma mark - UITableViewDelegate Methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return _panelItems.count == 0 ? CGFLOAT_MIN:44;
    return 170.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) return _panelItems.count == 0 ? CGFLOAT_MIN:8.0f;
    return 8.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    if (section == 0) {
        SCDevicePatrolPanelViewCell *cell = [tableView dequeueCellName:@"SCDevicePatrolPanelViewCell" indexPath:indexPath];
        [self configPanelCell:cell row:row];
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[UITableViewCell sc_className] forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell.contentView addSubview:self.remarkView];
    [self.remarkView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.trailing.mas_equalTo(0);
        make.height.mas_equalTo(80);
    }];
    
    [cell.contentView addSubview:self.photoView];
    [self.photoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.remarkView.mas_bottom).offset(10);
        make.leading.mas_equalTo(15);
        make.trailing.mas_equalTo(-15);
        make.bottom.mas_equalTo(-15);
    }];
    return cell;
}

#pragma mark - UITextViewDelegate Methods

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [self cacheAllValues];
        [self.remarkView resignFirstResponder];
        return NO;
    }
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    [self cacheAllValues];
}

#pragma mark - UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self cacheAllValues];
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self cacheAllValues];
}

#pragma mark - Config Cells Methods

- (void)configPanelCell:(SCDevicePatrolPanelViewCell *)cell
                    row:(NSInteger)row {
    
    SCDevicePatrolPanelItem *item = (SCDevicePatrolPanelItem *)_panelItems[row];
    [cell setUpWithPanelItem:item allowInput:YES];
    cell.dateField.delegate = self;
    cell.dateField.pattern = kPlanNumberRegular;
    self.panelFields[row] = cell.dateField;
    cell.separatorInset = UIEdgeInsetsMake(0.f, 15.0f, 0.f, 15.0f);
}

#pragma mark - User Action Methods
// 提交事件
- (void)submitButtonAction {
    [self.view endEditing:YES];
    if ([self checkPanelContent]) {
        if (self.photoView.images.count == 0) {
            [SVProgressHUD showErrorWithStatus:@"请上传图片" duration:1.5 dismiss:nil];
            return;
        }
        @weakify(self)
        self.submitButton.enabled = NO;
        self.laterSubmitButton.enabled = NO;
        [SVProgressHUD showWithStatus:@"正在上传设备巡检数据"];
        NSString *remark = ([[self.remarkString trim] length] > 0)?self.remarkString:@"巡检结果：已完成巡检。";
        SCDevicePatrolUploadItem *uploadItem = [[SCDevicePatrolUploadItem alloc] initWithDevicePatrolCellDBItem:_cellItem createTime:[NSDateHelper genStringFromCurrentDate] remark:remark panelContent:[self genPatrolInfoJSONString] imgNames:nil];
        uploadItem.images = self.photoView.images;
        [SCUploadItemManager uploadDevicePatrolItem:uploadItem success:^{
            @strongify(self)
            self.cellItem.patrolStatus = SCDevicePatrolStatusProcessed;
            if (self.cellItem.patrolType == SCDevicePatrolTypeNotBLE) {
                //必须重置为蓝牙方式，否则列表页刷新就会把它过滤掉
                self.cellItem.patrolType = SCDevicePatrolTypeBLE;
            }
            [self.cellItem commit];
            [SVProgressHUD showSuccessWithStatus:@"成功上传设备巡检数据" duration:2.0 dismiss:^{
                if (self.finish) {
                    self.finish(self.cellItem);
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kDevicePatrolItemChangeNotification object:nil];
                NSInteger index = [[self.navigationController viewControllers] indexOfObject:self];
                [self.navigationController popToViewController:self.navigationController.viewControllers[index-2] animated:YES];
            }];
        } failure:^(NSError *error) {
            self.submitButton.enabled = YES;
            self.laterSubmitButton.enabled = YES;
            [SCAlertHelper handleError:error];
        }];
    } else {
        [SVProgressHUD showErrorWithStatus:@"抄表度数不可为空" duration:1.0 dismiss:nil];
    }
}

// 稍后上传
- (void)laterSubmitButtonAction {
    [self.view endEditing:YES];
    if ([self checkPanelContent]) {
        if (self.photoView.images.count == 0) {
            [SVProgressHUD showErrorWithStatus:@"请上传图片" duration:1.5 dismiss:nil];
            return;
        }
        [SVProgressHUD showWithStatus:@"正在缓存设备巡检数据"];
        [self.submitButton setEnabled:NO];
        [self.laterSubmitButton setEnabled:NO];
        if ([self.photoView.photos count] > 0) {
            @weakify(self)
            [SCSavePhotoManager savePhotoToDocumentWithUploadImages:self.photoView.photos success:^(NSArray *photoNames) {
                @strongify(self)
                NSString *imgNames = [photoNames componentsJoinedByString:@","];
                [self cacheDevicePatrolUsingImgUrls:imgNames];
            } failure:^(NSError *error) {
                [self.submitButton setEnabled:YES];
                [self.laterSubmitButton setEnabled:YES];
                [SVProgressHUD showErrorWithStatus:@"缓存设备巡检图片数据失败" duration:1.0 dismiss:nil];
            }];
        } else {
            [self cacheDevicePatrolUsingImgUrls:nil];
        }
    } else {
        [SVProgressHUD showErrorWithStatus:@"抄表度数不可为空" duration:1.0 dismiss:nil];
    }
}

#pragma mark - Private Methods

- (void)cacheDevicePatrolUsingImgUrls:(NSString *)imgUrls {
    NSString *remark = ([[self.remarkString trim] length] > 0)?self.remarkString:@"巡检结果：已完成巡检。";
    SCDevicePatrolUploadItem *uploadItem = [[SCDevicePatrolUploadItem alloc] initWithDevicePatrolCellDBItem:_cellItem createTime:[NSDateHelper genStringFromCurrentDate] remark:remark panelContent:[self genPatrolInfoJSONString] imgNames:imgUrls];
    if ([uploadItem commitWithType:SCUploadItemTypeDevicePatrol]) {
        self.cellItem.patrolStatus = SCDevicePatrolStatusUpload;
        if (self.cellItem.patrolType == SCDevicePatrolTypeNotBLE) {
            //必须重置为蓝牙方式，否则列表页刷新就会把它过滤掉
            self.cellItem.patrolType = SCDevicePatrolTypeBLE;
        }
        // 修改数据后，更新本地数据库
        if ([self.cellItem commit]) {
            [self.submitButton setEnabled:YES];
            [self.laterSubmitButton setEnabled:YES];
            @weakify(self)
            [SVProgressHUD showSuccessWithStatus:kCacheDevicePatrolDataSucceed duration:1.0 dismiss:^{
                @strongify(self)
                if (self.finish) {
                    self.finish(self.cellItem);
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kDevicePatrolItemChangeNotification object:nil];
                NSInteger index = [[self.navigationController viewControllers] indexOfObject:self];
                [self.navigationController popToViewController:self.navigationController.viewControllers[index-2] animated:YES];
            }];
        } else {
            [self.submitButton setEnabled:YES];
            [self.laterSubmitButton setEnabled:YES];
            [SVProgressHUD showErrorWithStatus:@"数据库更新失败" duration:1.0 dismiss:nil];
        }
    } else {
        [self.submitButton setEnabled:YES];
        [self.laterSubmitButton setEnabled:YES];
        [SVProgressHUD showErrorWithStatus:kCacheDevicePatrolDataFailured duration:1.0 dismiss:nil];
    }
}

- (void)prestorePanelFields {
    NSInteger count = [_cellItem.patrolPanelArray count];
    if (count > 0) {
        for (NSInteger i = 0; i < count; i++) {
            [self.panelFields addObject:[WTReTextField new]];
        }
    }
}

- (void)addGesture {
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(keyboardHide:)];
    //设置成NO表示当前控件响应后会传播到其他控件上，默认为YES。
    tapGestureRecognizer.cancelsTouchesInView = NO;
    //将触摸事件添加到当前view
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)keyboardHide:(UITapGestureRecognizer*)tap {
    [self cacheAllValues];
    [self.view endEditing:YES];
}

- (void)cacheAllValues {
    self.remarkString = [self.remarkView.text trim];
    if ([_panelItems count] > 0) {
        NSInteger count = [_panelItems count];
        for (NSInteger i = 0; i < count; i++) {
            WTReTextField *field = self.panelFields[i];
            NSString *panelData = field.text;
            NSLog(@"------缓存的抄表数据 = %@------",panelData);
            if ([[panelData trim] length] > 0) {
                SCDevicePatrolPanelItem *item = (SCDevicePatrolPanelItem *)_panelItems[i];
                item.panelData = panelData;
            }
        }
    }
}

/**
 *  @author xujunhao, 16-08-03 14:08:24
 *
 *  第一响应者处理
 */
- (void)dispatchFirstResponser {
    if ([_panelItems count] == 0) {
        [self.remarkView becomeFirstResponder];
    } else {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        SCDevicePatrolPanelViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [cell.dateField becomeFirstResponder];
    }
}

/**
 *  生成抄表内容JSONString
 *
 *  @return 超标内容的JSON字符串
 */
- (NSString *)genPatrolInfoJSONString {
    if ([_panelItems count] >0) {
        NSArray *JSONArray = [SCDevicePatrolPanelItem mj_keyValuesArrayWithObjectArray:[_panelItems mutableCopy]];
        return [SCOrderHelper genJSONStringFromObject:JSONArray];
    }
    return nil;
}

#pragma mark - UIContent SetUp Method

- (void)setUpUIContent {
    self.navigationItem.title = _cellItem.name;
    [self prestorePanelFields];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:[UITableViewCell sc_className]];
    [self.tableView registerCellWithCellName:@"SCDevicePatrolPanelViewCell"];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    
    self.footerView = [[SCTableFooterView alloc] initWithButtonItems:self.submitButton, self.laterSubmitButton, nil];
    self.tableView.tableFooterView = self.footerView;
    
    [self addGesture];
    
    [self.submitButton setEnabled:NO];
    [self.laterSubmitButton setEnabled:NO];
    
    [self validateBeacon];
}

#pragma mark - Check PanelData Method

- (BOOL)checkPanelContent {
    NSInteger count = [_panelItems count];
    if (count > 0) {
        BOOL check = YES;
        for (NSInteger i = 0; i < count; i++) {
            SCDevicePatrolPanelItem *item = (SCDevicePatrolPanelItem *)_panelItems[i];
            if ([[item.panelData trim] length] > 0) {
                check = YES;
            } else {
                check = NO;
                break;
            }
        }
        return check;
    }
    return YES;
}

#pragma mark - iBeacon Check Method

- (void)validateBeacon {
    if (_sectionItem.patrolType == SCDevicePatrolTypeBLE||_sectionItem.patrolType == SCDevicePatrolTypeNotBLE) {
        //校验iBeacon
        @weakify(self)
        [[SCBeaconManager sharedInstance] scanBeaconUsingUUIDString:_sectionItem.UUID major:[_sectionItem.major hexValue] minor:[_sectionItem.minor hexValue] success:^{
            @strongify(self)
            GCD_MAIN(^{
                self.cellItem.patrolType = SCDevicePatrolTypeBLE;
                [self.submitButton setEnabled:YES];
                [self.laterSubmitButton setEnabled:YES];
            });
        } failure:^(NSError *error) {
            @strongify(self)
            GCD_MAIN(^{
                self.cellItem.patrolType = SCDevicePatrolTypeNotBLE;
                [self.submitButton setEnabled:YES];
                [self.laterSubmitButton setEnabled:YES];
            });
        }];
    } else {
        [self.submitButton setEnabled:YES];
        [self.laterSubmitButton setEnabled:YES];
    }
}

#pragma mark - Accessor Method

- (NSMutableArray *)panelItems {
    if (!_panelItems) {
        _panelItems = [NSMutableArray new];
    }
    return _panelItems;
}

- (NSMutableArray *)panelFields {
    if (!_panelFields) {
        _panelFields = [NSMutableArray new];
    }
    return _panelFields;
}

@end
