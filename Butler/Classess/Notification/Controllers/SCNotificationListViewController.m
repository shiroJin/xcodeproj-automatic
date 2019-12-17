//
//  SCNotificationListViewController.m
//  Butler
//
//  Created by quanbinjin on 2018/6/13.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCNotificationListViewController.h"
#import "SCNotificationDetailViewController.h"

#import <UITableView+FDTemplateLayoutCell/UITableView+FDTemplateLayoutCell.h>
#import "SCNotificationListAPI.h"
#import "SCNotificationModel.h"
#import "SCNoticeSetReadAPI.h"
#import "SCNotificationManager.h"

#import "SCBaseWebViewController.h"
#import "SCWebViewController.h"
#import "SCNotificationTableViewCell.h"
#import "SCNoticeTextTableViewCell.h"
#import "SCNotificationTimeTableViewCell.h"

@interface SCNotificationListViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) SCEmptyDataSetAssistant *emptyDataSet;
@property (strong, nonatomic) UIBarButtonItem *rightItem;

@property (strong, nonatomic) SCNotificationListAPI *notificationListAPI;
@property (assign, nonatomic) BOOL fetchUnread;
@property (strong, nonatomic) NSMutableArray *dataList;

@end

@implementation SCNotificationListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self setupView];
    [self setupData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)setupView {
    self.navigationItem.title = @"通知";
    self.view.backgroundColor = [UIColor whiteColor];
    
    _rightItem = [[UIBarButtonItem alloc] initWithTitle:@"未读" style:UIBarButtonItemStyleDone target:self action:@selector(unreadList)];
    self.navigationItem.rightBarButtonItem = _rightItem;
    
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerNib:[UINib nibWithNibName:[SCNotificationTableViewCell sc_className] bundle:nil] forCellReuseIdentifier:[SCNotificationTableViewCell sc_className]];
    [self.tableView registerNib:[UINib nibWithNibName:[SCNotificationTimeTableViewCell sc_className] bundle:nil] forCellReuseIdentifier:[SCNotificationTimeTableViewCell sc_className]];
    [self.tableView registerNib:[UINib nibWithNibName:[SCNoticeTextTableViewCell sc_className] bundle:nil] forCellReuseIdentifier:[SCNoticeTextTableViewCell sc_className]];

    @weakify(self);
    self.tableView.mj_header = [SCCustomRefreshHeader headerWithRefreshingBlock:^{
        @strongify(self);
        // mark: refresh noti
        [self fetchNotificationEntities];
    }];
    
    self.tableView.mj_footer = [SCCustomRefreshFooter footerWithRefreshingBlock:^{
        @strongify(self);
        // mark: fetch more noti
        [self fetchMoreNotificationEntities];
    }];
    [self.tableView.mj_footer endRefreshingWithNoMoreData];
    
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        
        if (UI_IS_IPHONEX()) {
            self.tableView.insetsContentViewsToSafeArea = NO;
            self.tableView.mj_footer.ignoredScrollViewContentInsetBottom = 34;
        }
    }
}

- (void)setupData {
    [self.tableView.mj_header beginRefreshing];
}

- (void)reloadUI {
    self.emptyDataSet.builder.isShowEmptyView = true;
    
    if (!self.notificationListAPI.page.hasMore) {
        [self.tableView.mj_footer endRefreshingWithNoMoreData];
    } else {
        [self.tableView.mj_footer resetNoMoreData];
    }

    [self.tableView reloadData];
}

#pragma mark - Events

- (void)fetchNotificationEntities {
    self.notificationListAPI = [SCNotificationListAPI new];
    self.notificationListAPI.fetchUnread = self.fetchUnread;
    
    @weakify(self);
    [self.notificationListAPI startWithFirstPageCompletionSuccess:^(id responseDataDict) {
        @strongify(self);
        // parse data
        if (![responseDataDict isKindOfClass:[NSDictionary class]]) {
            [self.tableView.mj_header endRefreshing];
            return;
        }
        NSArray *list = [SCNotificationModel mj_objectArrayWithKeyValuesArray:responseDataDict[@"resultList"]];
        self.dataList = list.mutableCopy;
        
        [self.tableView.mj_header endRefreshing];
        [self reloadUI];
    } failure:^(NSError *error) {
        @strongify(self);
        [self.tableView.mj_header endRefreshing];
        [SCAlertHelper handleError:error];
    }];
}

- (void)fetchMoreNotificationEntities {
    @weakify(self);
    [self.notificationListAPI startWithNextPageCompletionSuccess:^(id responseDataDict) {
        @strongify(self);
        if (![responseDataDict isKindOfClass:[NSDictionary class]]) {
            [self.tableView.mj_header endRefreshing];
            return;
        }
        NSArray *list = [SCNotificationModel mj_objectArrayWithKeyValuesArray:responseDataDict[@"resultList"]];
        [self.dataList addObjectsFromArray:list];
        
        [self.tableView.mj_footer endRefreshing];
        [self reloadUI];
    } failure:^(NSError *error) {
        @strongify(self);
        [self.tableView.mj_footer endRefreshing];
        [SCAlertHelper handleError:error];
    }];
}

#pragma mark - Events

- (void)unreadList {
    self.fetchUnread = !self.fetchUnread;
    NSString *title = self.fetchUnread ? @"全部" : @"未读";
    self.rightItem.title = title;
    
    [self.tableView.mj_header beginRefreshing];
}

#pragma mark - TableView Delegate & DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataList.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        return 50.f;
    } else {
        SCNotificationModel *notice = self.dataList[indexPath.section];
        if (notice.imgUrl.length > 0) {
            return [tableView fd_heightForCellWithIdentifier:[SCNotificationTableViewCell sc_className] cacheByKey:notice.noticeId.stringValue configuration:^(SCNotificationTableViewCell *cell) {
                [cell configWithNotification:notice];
            }];
        } else {
            return [tableView fd_heightForCellWithIdentifier:[SCNoticeTextTableViewCell sc_className] cacheByKey:notice.noticeId configuration:^(SCNoticeTextTableViewCell *cell) {
                [cell configWithNotification:notice];
            }];
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        SCNotificationTimeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCNotificationTimeTableViewCell sc_className] forIndexPath:indexPath];
        [cell configWithNotification:self.dataList[indexPath.section]];
        return cell;
    } else {
        SCNotificationModel *notice = self.dataList[indexPath.section];
        if (notice.imgUrl.length > 0) {
            SCNotificationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCNotificationTableViewCell sc_className] forIndexPath:indexPath];
            [cell configWithNotification:self.dataList[indexPath.section]];
            return cell;
        } else {
            SCNoticeTextTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCNoticeTextTableViewCell sc_className] forIndexPath:indexPath];
            [cell configWithNotification:notice];
            return cell;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section >= self.dataList.count) return;
    // 点击时间cell避免跳转
    if (indexPath.row == 0) return;
    
    SCNotificationModel *model = self.dataList[indexPath.section];
    // 标记通知已读
    [self markNoticeReaded:model];
    // 统计
    [SCTrackManager trackEvent:kWorkbenchMineNoticeCardClick attributes:@{@"noticeId":model.noticeId}];
    
    // 跳转
    if (model.skipData.url && model.skipData.url.length > 0) {
        SCBaseWebViewController *vc = [[SCBaseWebViewController alloc] init];
        vc.urlString =  model.loadUrlString;
        
        NSLog(@"vc.urlString==%@==",vc.urlString);
        @weakify(self);
        vc.callHanderBlock = ^(id object) {
            @strongify(self);
            /// 手动置为已签收
            model.signStatus = 2;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        };
        [self.navigationController pushViewController:vc animated:YES];
        
    } else {
        SCNotificationDetailViewController *target = [[SCNotificationDetailViewController alloc] init];
        target.detailId = model.noticeId;
        target.scopeType = model.noticeScope;
        target.sendType = model.skipData.extraObject.sendType;
        target.sign = model.skipData.extraObject.sign;
        [self.navigationController pushViewController:target animated:YES];
    }
}

- (void)markNoticeReaded:(SCNotificationModel *)notice {
    @weakify(self)
    [SCNotificationManager dealNoticeReaded:notice.noticeId scopeType:notice.noticeScope success:^(id responseDataDict) {
        @strongify(self)
        BOOL isUnread = self.fetchUnread;
        if (isUnread) {
            if ([self.dataList containsObject:notice]) {
                [self.dataList removeObject:notice];
            }
        } else {
            notice.isRead = YES;
        }
        [self.tableView reloadData];
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
    }];
}

#pragma mark - Accessor

- (SCEmptyDataSetAssistant *)emptyDataSet {
    if (!_emptyDataSet) {
        _emptyDataSet = [SCEmptyDataSetAssistant emptyForContentView:self.tableView builderBlock:^(SCEmptyDataSetBuilder *builder) {
            builder.emptyImage = [UIImage imageNamed:@"notice_no_result"];
            builder.emptyTitle = @"暂无通知";
            builder.isShowEmptyView = false;
            builder.verticalOffset = -100.f;
            builder.emptyTitleFont = [UIFont systemFontOfSize:12.f];
        } tappedBlock:^{
        }];
    }
    return _emptyDataSet;
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
