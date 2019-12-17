//
//  SCAccountSwitchViewController.m
//  TownForRemain
//
//  Created by zhanghengyi on 2019/9/17.
//  Copyright © 2019 uama. All rights reserved.
//

#import "SCAccountSwitchViewController.h"
#import "SCLoginViewController.h"
#import "SCAccountSwitchCell.h"
#import "SCAccountSwitchAddCell.h"

#import "SCLocalStorageAccountsService.h"
#import "SCLoginAPI.h"
#import "SCBaseDBManager.h"
#import "SCAPNsHelper.h"
#import "SCUserAccountHelper.h"

#define kAccountLimit 5

@interface SCAccountSwitchViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
/**
 普通提示
 */
@property (weak, nonatomic) IBOutlet UILabel *normalTipsLabel;
/**
 删除提示
 */
@property (weak, nonatomic) IBOutlet UIView *deleteTipsView;

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (nonatomic) NSMutableArray *dataSourceMArray;

@property (nonatomic) BOOL isEditing;

@property (nonatomic) UIBarButtonItem *leftBarButtonItem;

@end

@implementation SCAccountSwitchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = HEXCOLOR(0xF0F2F2);
    self.collectionView.backgroundColor = HEXCOLOR(0xF0F2F2);
    
    [self.collectionView registerNib:[UINib nibWithNibName:[SCAccountSwitchCell sc_className] bundle:nil] forCellWithReuseIdentifier:[SCAccountSwitchCell sc_className]];
    [self.collectionView registerNib:[UINib nibWithNibName:[SCAccountSwitchAddCell sc_className] bundle:nil] forCellWithReuseIdentifier:[SCAccountSwitchAddCell sc_className]];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
    self.deleteTipsView.hidden = true;
    
    [self fetchLoginAccounts];
    
    self.leftBarButtonItem = self.navigationItem.leftBarButtonItem;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage createGradientImageFromColors:@[HEXCOLOR(0xF0F2F2), HEXCOLOR(0xF0F2F2)] gradientType:SCGradientTypeTopToBottom imgSize:CGSizeMake(SCREEN_WIDTH, self.navigationController.navigationBar.height + SCStatusBarHeight)] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = HEXCOLOR(0x333333);
    self.navigationController.navigationBar.titleTextAttributes =
    @{NSForegroundColorAttributeName: HEXCOLOR(0x333333),
      NSFontAttributeName: SC_TEXT_FONT_NAV_TITLE};
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage createGradientImageFromColors:@[SC_NAVBAR_BEGIN_COLOR, SC_NAVBAR_END_COLOR] gradientType:SCGradientTypeTopToBottom imgSize:CGSizeMake(SCREEN_WIDTH, self.navigationController.navigationBar.height + SCStatusBarHeight)] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.titleTextAttributes =
    @{NSForegroundColorAttributeName: [UIColor whiteColor],
      NSFontAttributeName: SC_TEXT_FONT_NAV_TITLE};
    [self.navigationItem.rightBarButtonItem setTintColor:[UIColor whiteColor]];
}

- (void)fetchLoginAccounts
{
    NSArray *combinedAccountWithCurrentUser = [[SCLocalStorageAccountsService sharedInstance] fetchLoginAccounts];
    self.dataSourceMArray = [SCLocalStorageAccount mj_objectArrayWithKeyValuesArray:combinedAccountWithCurrentUser];
    [self.collectionView reloadData];
    
    if (self.dataSourceMArray.count > 1 && !self.isEditing) {
        //如当前只有一个账号，隐藏清除按钮
        
        UIButton *clearAccountRecordBtn = [[UIButton alloc] init];
        [clearAccountRecordBtn setTitle:@"清除账号记录" forState:UIControlStateNormal];
        clearAccountRecordBtn.titleLabel.font = [UIFont systemFontOfSize:15.0];
        [clearAccountRecordBtn setTitleColor:HEXCOLOR(0x333333) forState:UIControlStateNormal];
        [clearAccountRecordBtn addTarget:self action:@selector(clearAccountRecordBtnAction) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:clearAccountRecordBtn];
         
    }
}

/**
 是否可以添加账号

 @return <#return value description#>
 */
- (BOOL)shouldAddAccounts
{
    return self.dataSourceMArray.count < kAccountLimit && !_isEditing;
}

#pragma UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    
    return self.dataSourceMArray.count + ([self shouldAddAccounts] ? 1 : 0);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self shouldAddAccounts] && indexPath.item == self.dataSourceMArray.count) {
        //添加账号
        SCAccountSwitchAddCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[SCAccountSwitchAddCell sc_className] forIndexPath:indexPath];
        return cell;
    } else {
        SCAccountSwitchCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[SCAccountSwitchCell sc_className] forIndexPath:indexPath];
        SCLocalStorageAccount *account = self.dataSourceMArray[indexPath.item];
        [cell loadData:account];
        @weakify(self);
        cell.deleteActionBlock = ^{
            @strongify(self);
            [self showDeleteAccountTips:account.userId item:indexPath.item];
        };
        [cell deleteAction:self.isEditing];
        return cell;
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(SCREEN_WIDTH / 3, 150);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return CGFLOAT_MIN;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return CGFLOAT_MIN;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isEditing) {
        SCLocalStorageAccount *account = self.dataSourceMArray[indexPath.item];
        [self showDeleteAccountTips:account.userId item:indexPath.item];
    }
    else if ([self shouldAddAccounts] && indexPath.item == self.dataSourceMArray.count) {
        //添加账号
        SCLog(@"添加账号");
        [self gotoLoginPage:nil];
    } else {
        SCLocalStorageAccount *account = self.dataSourceMArray[indexPath.item];
        BOOL isCurrentUser = [account.userId isEqualToString:[SCUser currentLoggedInUser].userId];
        if (!isCurrentUser) {
            //切换登录
            SCLog(@"切换账号");
            [self switchAccountLoginAction:account];
        }
    }
}

#pragma - Actions

- (void)clearAccountRecordBtnAction
{
    [self refreshEditingStatus:YES];

    UIButton *clearAccountRecordBtn = [[UIButton alloc] init];
    [clearAccountRecordBtn setTitle:@"完成" forState:UIControlStateNormal];
    clearAccountRecordBtn.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [clearAccountRecordBtn setTitleColor:HEXCOLOR(0x333333) forState:UIControlStateNormal];
    [clearAccountRecordBtn addTarget:self action:@selector(clearDoneAction) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:clearAccountRecordBtn];
}

- (void)clearDoneAction
{
    
    [self refreshEditingStatus:NO];
    //完成

    UIButton *clearAccountRecordBtn = [[UIButton alloc] init];
    [clearAccountRecordBtn setTitle:@"清除账号记录" forState:UIControlStateNormal];
    clearAccountRecordBtn.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [clearAccountRecordBtn setTitleColor:HEXCOLOR(0x333333) forState:UIControlStateNormal];
    [clearAccountRecordBtn addTarget:self action:@selector(clearAccountRecordBtnAction) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:clearAccountRecordBtn];
}

- (void)showDeleteAccountTips:(NSString *)userId item:(NSInteger)item
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"是否删除该账号？" message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }];
    UIAlertAction *okAlertAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[SCLocalStorageAccountsService sharedInstance] deleteAccountAction:userId];
        [self fetchLoginAccounts];
        
    }];
    [alert addAction:cancel];
    [alert addAction:okAlertAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)switchAccountLoginAction:(SCLocalStorageAccount *)account
{
    if (!account.loginUserName || !account.loginPasswdSecreted) {
        [self showAccountAbnormalDialogue:account];
    } else {
        [self actionForLogin:account successBlock:^{
            // 更新新登录的账号信息
            [SCLocalStorageAccount shared].loginUserName = account.loginUserName;
            [SCLocalStorageAccount shared].loginPasswdSecreted = account.loginPasswdSecreted;
            [[SCLocalStorageAccountsService sharedInstance] switchAccountLoginAction];
        } failBlock:^{
            [self showAccountAbnormalDialogue:account];
        }];
    }
}

/**
 显示账号异常对话框

 @param account 账号
 */
- (void)showAccountAbnormalDialogue:(SCLocalStorageAccount *)account
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"账号信息已失效，是否重新登录" message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"否" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }];
    UIAlertAction *okAlertAction = [UIAlertAction actionWithTitle:@"是" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self gotoLoginPage:account];
        
    }];
    [alert addAction:cancel];
    [alert addAction:okAlertAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)gotoLoginPage:(SCLocalStorageAccount *)account
{
    //跳转登录页面
    SCLoginViewController *loginVC = [[SCLoginViewController alloc] initWithNibName:[SCLoginViewController sc_className] bundle:nil];
    loginVC.isFromAccountSwitchAdd = YES;
    loginVC.account = account;
    [self.navigationController pushViewController:loginVC animated:YES];
}

- (void)refreshEditingStatus:(BOOL)isEdit
{
    self.isEditing = isEdit;
    self.deleteTipsView.hidden = !isEdit;
    self.normalTipsLabel.hidden = isEdit;
    [self.collectionView reloadData];
    if (isEdit) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:self action:nil];
    } else {
        self.navigationItem.leftBarButtonItem = self.leftBarButtonItem;
    }
}

/// 登录事件
- (void)actionForLogin:(SCLocalStorageAccount *)account successBlock:(void(^)(void))successBlock failBlock:(void(^)(void))failBlock {
    
    SCLoginAPI *loginAPI = [[SCLoginAPI alloc] init];
    loginAPI.loginType = SCLoginTypeNormal;
    loginAPI.loginName = account.loginUserName;
    loginAPI.loginPwd = account.loginPasswdSecreted;
    [SVProgressHUD showWithStatus:@"正在登录..."];
    @weakify(self);
    [loginAPI startWithCompletionWithSuccess:^(id responseDataDict) {
        @strongify(self);
        // 先记录账号
        [[NSUserDefaults standardUserDefaults] setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] forKey:kRecordedAppVersion];
        [[NSUserDefaults standardUserDefaults] setValue:[account.loginUserName trimAnySpace] forKey:kLoggedInUserName];
        [[NSUserDefaults standardUserDefaults] synchronize];
        // 返回数据解析
        SCUser *userModel = [SCUser mj_objectWithKeyValues:responseDataDict];
        userModel.userImgUrl = responseDataDict[@"userImgUrl"];
        // 园区账号
        if (userModel) {
            [SCUser saveUserInfo:userModel];
        }
        
        if (successBlock) {
            successBlock();
        }
        
        [self communityAccountHandle];
    } failure:^(NSError *error) {
        [SVProgressHUD dismiss];
        if (failBlock) {
            failBlock();
        } else {
            [SCAlertHelper handleError:error];
        }
    }];
}

// 账号处理
- (void)communityAccountHandle {
    SCUser *user = [SCUser currentLoggedInUser];
    if (![user.userId isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:kLoggedInUserId]]) {
        //需要清除角标、更新时间、离线数据和待上传数据
        [SCBaseDBManager clearAllDBData];
    }
    
    // 写在判断是否是同一用户的逻辑之后
    [[NSUserDefaults standardUserDefaults] setObject:user.userId forKey:kLoggedInUserId];
    [[NSUserDefaults standardUserDefaults] setObject:user.communityId forKey:kLoggedInCommunityId];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // 注册推送
    [[SCAPNsHelper sharedInstance] registerJPushUsingUserAlias:user.alias];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    [SVProgressHUD showSuccessWithStatus:@"登录成功！" duration:2.0 dismiss:nil];
    [SCUserAccountHelper handleWithWindow:[[[UIApplication sharedApplication] delegate] window] removeAPNs:NO];
}
@end
