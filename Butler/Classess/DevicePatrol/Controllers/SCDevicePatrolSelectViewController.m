//
//  SCDevicePatrolSelectViewController.m
//  Butler
//
//  Created by abeihaha on 2017/1/4.
//  Copyright © 2017年 UAMA Inc. All rights reserved.
//

#import "SCDevicePatrolSelectViewController.h"
#import "UITableView+FDTemplateLayoutCell.h"
#import "SCDevicePatrolViewCell.h"
#import "SCDevicePatrolGroupHeaderViewCell.h"
#import "SCDevicePatrolSectionDBItem.h"
#import "SCDevicePatrolCellDBItem.h"
#import "SCDevicePatrolFBViewController.h"
#import "SCDevicePatrolDetailViewController.h"

@interface SCDevicePatrolSelectViewController ()

@property (assign, nonatomic) SCDevicePatrolType patrolType;//巡检方式：蓝牙、非蓝牙
@property (strong, nonatomic) SCDevicePatrolSectionDBItem *item;//巡检设备分组数据
@property (copy, nonatomic) PatrolSectionItemStatusChangeBlock change;
@property (assign, nonatomic) BOOL shoudRefresh;//从巡检反馈页成功提交后跳转至本页需要刷新数据
@property (strong, nonatomic) NSMutableArray *items;//巡检设备列表

@end

@implementation SCDevicePatrolSelectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setUpUIContent];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //    if (self.shoudRefresh) {
    //        [self.tableView reloadData];
    //        self.shoudRefresh = NO;
    //    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Public Method

- (void)setUpWithPatrolSectionItem:(SCDevicePatrolSectionDBItem *)item
                        patrolType:(SCDevicePatrolType)patrolType
                            change:(PatrolSectionItemStatusChangeBlock)change {
    _patrolType = patrolType;
    _item = item;
    _item.patrolType = item.patrolType;
    _change = change;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rowNum = 1;
    rowNum += [_items count];
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
        [self configPatrolViewCell:cell atIndexPath:indexPath];
        return cell;
    }
    return [UITableViewCell new]; //fixed by 囧 以防崩溃;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger row = indexPath.row;
    if (row != 0) {
        SCDevicePatrolCellDBItem *item = (SCDevicePatrolCellDBItem *)self.items[row-1];
        [self push2NextVC:item index:row-1];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    if (row == 0) {
        return [tableView fd_heightForCellWithIdentifier:@"SCDevicePatrolGroupHeaderViewCell"
                                        cacheByIndexPath:indexPath configuration:^(SCDevicePatrolGroupHeaderViewCell *cell) {
                                            [self configGroupHeaderCell:cell
                                                            atIndexPath:indexPath];
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
    [cell setUpWithPatrolSectionItem:_item
                             checked:YES
                 beginBLEPatrolBlock:nil
                  beginQRPatrolBlock:nil];
}

- (void)configPatrolViewCell:(SCDevicePatrolViewCell *)cell
                 atIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [indexPath row];
    SCDevicePatrolCellDBItem *item = (SCDevicePatrolCellDBItem *)self.items[row-1];
    [cell setUpWithItem:item];
    [cell setUserInteractionEnabled:YES];
}


#pragma mark - SetUp UIContent Method

- (void)setUpUIContent {
    self.navigationItem.title = @"设备选择";
    [self.tableView registerCellWithCellName:@"SCDevicePatrolViewCell"];
    [self.tableView registerCellWithCellName:@"SCDevicePatrolGroupHeaderViewCell"];
    self.tableView.estimatedRowHeight = 74.0f;
    if ([_item.items count] > 0) {
        [self.items addObjectsFromArray:_item.items];
    }
    self.edgesForExtendedLayout = UIRectEdgeNone;
}

#pragma mark - Accessor Methods

- (NSMutableArray *)items {
    if (!_items) {
        _items = [NSMutableArray new];
    }
    return _items;
}

#pragma mark - Private Methods

- (void)push2NextVC:(SCDevicePatrolCellDBItem *)cellItem
              index:(NSInteger)index {
    switch (cellItem.patrolStatus) {
        case SCDevicePatrolStatusExpire:
        case SCDevicePatrolStatusWaiting: {
            [self push2PatrolFeedBackVC:cellItem
                                  index:index];
            break;
        }
        case SCDevicePatrolStatusProcessed: {
            [self push2PatrolDetailVC:cellItem];
            break;
        }
            
        case SCDevicePatrolStatusUpload: {
            [SVProgressHUD showErrorWithStatus:@"设备已巡检，请尽快上传巡检信息" duration:1.0 dismiss:nil];
        } break;
        default:
            break;
    }
}

/**
 *  @author xujunhao, 16-07-31 12:07:05
 *
 *  进入巡检反馈页面
 *
 *  @param item cellItem
 */
- (void)push2PatrolFeedBackVC:(SCDevicePatrolCellDBItem *)item
                        index:(NSInteger)index {
    SCDevicePatrolFBViewController *fbVC = [[SCDevicePatrolFBViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolFBViewController class]) bundle:nil];
    item.patrolType = self.patrolType;
    __block SCDevicePatrolSectionDBItem *blockItem = self.item;
    __block NSMutableArray *blockItems = self.items;
    if (![item canExecute]) {
        [SVProgressHUD showErrorWithStatus:@"您不是该任务的执行人" duration:1.5 dismiss:nil];
        return;
    }
    @weakify(self)
    [fbVC setUpWithCellItem:item
              inSectionItem:_item
                      chage:^(SCDevicePatrolCellDBItem *item) {
                          @strongify(self)
                          if (item) {
                              [blockItems replaceObjectAtIndex:index
                                                    withObject:item];
                          }
                          blockItem.items = [blockItems mutableCopy];
                          [self.tableView reloadData];
                          if (self.change) {
                              self.change(self.item);
                          }
                      }];
    [self.navigationController pushViewController:fbVC animated:YES];
}

/**
 *  @author xujunhao, 16-07-31 12:07:18
 *
 *  进入巡检完成详情页
 *
 *  @param item cellItem
 */
- (void)push2PatrolDetailVC:(SCDevicePatrolCellDBItem *)item {
    SCDevicePatrolDetailViewController *detailVC = [[SCDevicePatrolDetailViewController alloc] initWithNibName:NSStringFromClass([SCDevicePatrolDetailViewController class]) bundle:nil];
    [detailVC setUpWithCellItem:item];
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end
