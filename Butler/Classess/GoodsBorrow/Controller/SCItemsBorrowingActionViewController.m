//
//  SCItemsBorrowingViewController.m
//  SuperCommunity
//
//  Created by anlingling on 2019/3/28.
//  Copyright © 2019 uama. All rights reserved.
//

#import "SCItemsBorrowingActionViewController.h"

#import "SCGoodsBorrowingActionCategoryTableViewCell.h"
#import "SCGoodsBorrowingActionItemTableViewCell.h"
#import "SCGoodsBorrowingActionItemCategoryHeaderView.h"

#import "SCGoodsBorrowFetccGoodsAPI.h"
#import "SCGoodsBorrowingCategory.h"
#import "SCGoodsBorrowingItem.h"

@interface SCItemsBorrowingActionViewController () <UITableViewDelegate, UITableViewDataSource> {
    
    BOOL _isRelate;
    // 选中分类
    SCGoodsBorrowingCategory *_selectedCategory;
    NSMutableArray *_dataArray;
}

// 借用分类
@property (weak, nonatomic) IBOutlet UITableView *categoryTableView;
// 借用物品列表
@property (weak, nonatomic) IBOutlet UITableView *itemsTableView;

// 借用内容BG
@property (weak, nonatomic) IBOutlet UIView *selectedBGView;
// 借用内容label
@property (weak, nonatomic) IBOutlet UILabel *selectedL;
// 选中内容高度约束
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *selectedHConstraint;

// 确认借用按钮
@property (weak, nonatomic) IBOutlet UIButton *borrowButton;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *buttomToBottom;

// 借出商品数组
@property (strong, nonatomic) NSMutableArray<SCGoodsBorrowingItem *> *borrowItemArray;

@property (strong, nonatomic) SCEmptyDataSetAssistant *emptyDataAssistant;

@end

@implementation SCItemsBorrowingActionViewController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"物品列表";
    // 设置背景色，默认隐藏
    self.selectedBGView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.selectedHConstraint.constant = 0;
    
    [self.categoryTableView registerNib:[UINib nibWithNibName:[SCGoodsBorrowingActionCategoryTableViewCell sc_className] bundle:nil] forCellReuseIdentifier:[SCGoodsBorrowingActionCategoryTableViewCell sc_className]];
    [self.itemsTableView registerNib:[UINib nibWithNibName:[SCGoodsBorrowingActionItemTableViewCell sc_className] bundle:nil] forCellReuseIdentifier:[SCGoodsBorrowingActionItemTableViewCell sc_className]];
    [self.itemsTableView registerClass:[SCGoodsBorrowingActionItemCategoryHeaderView class] forHeaderFooterViewReuseIdentifier:[SCGoodsBorrowingActionItemCategoryHeaderView sc_className]];
    
    self.borrowItemArray = [NSMutableArray array];
    [self loadData];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    self.buttomToBottom.constant = self.view.safeAreaInsets.bottom;
}


- (void)loadData {
    [SVProgressHUD show];
    SCGoodsBorrowFetccGoodsAPI *api = [[SCGoodsBorrowFetccGoodsAPI alloc] init];
    [api startWithCompletionWithSuccess:^(id responseDataDict) {
        [SVProgressHUD dismiss];
        NSMutableArray *array= [SCGoodsBorrowingCategory mj_objectArrayWithKeyValuesArray:responseDataDict];
        self->_dataArray = [array mutableCopy];
        if (self->_dataArray.count > 0) {
            self->_selectedCategory = self->_dataArray.firstObject;
            self->_selectedCategory.isSelected = YES;
        }
        // 做选中数据处理
        [self dealWithSelectitem];
        [self.categoryTableView reloadData];
        [self.itemsTableView reloadData];
    } failure:^(NSError *error) {
        [SCAlertHelper handleError:error];
    }];
    
}

- (void)dealWithSelectitem
{
//    做数据处理，如果r选中的物品，在这次物品列表中不存在，则删除这个物品，x需要做优化
    
    for (SCGoodsBorrowingItem *selectItem in self.selectGoods) {
        
        for (SCGoodsBorrowingCategory *category in _dataArray) {
            
            for (SCGoodsBorrowingItem *goodsItem in category.goodsList) {
                
                if ([selectItem.goodsId isEqualToString:goodsItem.goodsId]) {
                    if (selectItem.editNum > goodsItem.surplusNum) {
                        goodsItem.editNum = goodsItem.surplusNum;
                        goodsItem.num = goodsItem.surplusNum;
                    } else {
                        goodsItem.editNum = selectItem.editNum;
                        goodsItem.num = selectItem.num;
                    }
                    [self.borrowItemArray addObject:goodsItem];
                    category.num += goodsItem.editNum;
                }
            }
        }
    }
    [self showBottomView];
}



- (IBAction)borrowingAction:(UIButton *)sender {
    if (!self.borrowItemArray.count) {
        [SVProgressHUD showErrorWithStatus:@"请选择借用物品" duration:1.5 dismiss:nil];
        return;
    }
    if (self.selectBtnClick) {
        self.selectBtnClick([_borrowItemArray mutableCopy]);
    }
}

- (void)updateBorrowItemArrayWithCategory:(SCGoodsBorrowingCategory *)category item:(SCGoodsBorrowingItem *)item {
    
    // 如果借出数组中存在该对象且编辑了数量，更新数据信息
    if (item.num != item.editNum) {
        category.num += (item.editNum - item.num);
        item.num = item.editNum;
    }
    
    // 为了再次进来时，默认选中上次选中的
//    SCGoodsBorrowingItem *borrowItem;
//    for (SCGoodsBorrowingItem *borrowInnerItem in self.borrowItemArray) {
//        if ([item.goodsId isEqualToString:borrowInnerItem.goodsId]) {
//            borrowItem = borrowInnerItem;
//            break;
//        }
//    }
//
//    if (borrowItem) {
//        [self.borrowItemArray replaceObjectAtIndex:[self.borrowItemArray indexOfObject:borrowItem] withObject:item];
//    }
    
    if (item.num <= 0) {
        [self.borrowItemArray removeObject:item];
    }
    else {
        if (![self.borrowItemArray containsObject:item]) {
            [self.borrowItemArray addObject:item];
        }
    }
    //显示底部
    [self showBottomView];
    
    // 类型tableview刷新数据
    [self.categoryTableView reloadData];
}


- (void)showBottomView
{
    if (self.borrowItemArray.count > 0) {
        self.selectedHConstraint.constant = 30.f;
        NSString *content = @"";
        for (NSInteger i = 0; i < self.borrowItemArray.count; i++) {
            
            SCGoodsBorrowingItem *curItem = self.borrowItemArray[i];
            NSString *itemInfo = [NSString stringWithFormat:@"%@x%ld", curItem.goodsName, curItem.num];
            if (i != self.borrowItemArray.count - 1) {
                content = [content stringByAppendingString:[NSString stringWithFormat:@"%@; ", itemInfo]];
            }
            else {
                content = [content stringByAppendingString:itemInfo];
            }
        }
        self.selectedL.text = content;
    }
    else {
        self.selectedHConstraint.constant = 0.f;
    }
}


#pragma mark - emptyView


#pragma mark - UITableViewDelegate && UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.categoryTableView) {
        return 1;
    } else {
        return [_dataArray count];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (tableView == self.categoryTableView) {
        return [_dataArray count];
    } else {
        SCGoodsBorrowingCategory *category = _dataArray[section];
        return category.goodsList.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView == self.categoryTableView) {
        SCGoodsBorrowingActionCategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCGoodsBorrowingActionCategoryTableViewCell sc_className] forIndexPath:indexPath];
        SCGoodsBorrowingCategory *category = _dataArray[indexPath.row];
        [cell loadData:category];
        return cell;
        
    } else {
        // item
        SCGoodsBorrowingActionItemTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCGoodsBorrowingActionItemTableViewCell sc_className] forIndexPath:indexPath];
        SCGoodsBorrowingCategory *category = _dataArray[indexPath.section];
        SCGoodsBorrowingItem *item = category.goodsList[indexPath.row];
        @weakify(self)
        cell.numChangedBlock = ^{
            @strongify(self)
            [self updateBorrowItemArrayWithCategory:category item:item];
        };
        [cell loadData:item];
        
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.categoryTableView) {
        return 55.f;
    } else {
        return 95.f;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    if (tableView == self.categoryTableView) {
        return CGFLOAT_MIN;
    } else {
        return 25.f;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    // 最底部剩余30，用来适配内容信息
    if (tableView == self.categoryTableView) {
        return 30.f;
    } else {
        if (section == _dataArray.count - 1) {
            return 30.f;
        }
        return CGFLOAT_MIN;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (tableView == self.itemsTableView) {
        SCGoodsBorrowingActionItemCategoryHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[SCGoodsBorrowingActionItemCategoryHeaderView sc_className]];
        SCGoodsBorrowingCategory *category = _dataArray[section];
        headerView.content = ISNULL(category.categoryName);
        return headerView;
    } else {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if (_isRelate) {
        NSInteger topCellSection = [[[tableView indexPathsForVisibleRows] firstObject] section];
        NSInteger sectionNum = [tableView numberOfRowsInSection:section];
        if (tableView == self.itemsTableView && sectionNum > 0) {
            [self categoryTableViewSelectedWithIndexPath:[NSIndexPath indexPathForRow:topCellSection inSection:0]];
        }
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingFooterView:(UIView *)view forSection:(NSInteger)section {
    if (_isRelate) {
        NSInteger topCellSection = [[[tableView indexPathsForVisibleRows] firstObject] section];
        NSInteger sectionNum = [tableView numberOfRowsInSection:section];
        if (tableView == self.itemsTableView && sectionNum > 0) {
            [self categoryTableViewSelectedWithIndexPath:[NSIndexPath indexPathForRow:topCellSection inSection:0]];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.categoryTableView) {
        _isRelate = NO;
        SCGoodsBorrowingCategory *category = _dataArray[indexPath.row];
        category.isSelected = YES;
        _selectedCategory.isSelected = NO;
        _selectedCategory = category;
        
        [self categoryTableViewSelectedWithIndexPath:indexPath];
        NSInteger sectionNum = [tableView numberOfRowsInSection:indexPath.section];
        if (sectionNum > 0) {
            [self.itemsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:indexPath.row] atScrollPosition:UITableViewScrollPositionTop animated:YES];
        }
    } else {
        [self.itemsTableView deselectRowAtIndexPath:indexPath animated:NO];
    }
}

- (void)categoryTableViewSelectedWithIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.row >= _dataArray.count) {
        // 数组越界，不选中
        return;
    }

    // 更新数据信息
    _selectedCategory.isSelected = NO;
    SCGoodsBorrowingCategory *curSelectedCategory = _dataArray[indexPath.row];
    curSelectedCategory.isSelected = YES;
    _selectedCategory = curSelectedCategory;
    
    [self.categoryTableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    [self.categoryTableView reloadData];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    _isRelate = YES;
}

@end
