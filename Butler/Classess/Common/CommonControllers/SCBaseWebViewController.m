//
//  SCBaseWebViewController.m
//  Butler
//
//  Created by zhanglijiong on 2018/8/9.
//  Copyright © 2018年 UAMA Inc. All rights reserved.
//

#import "SCBaseWebViewController.h"
#import "WKWebView+SCTool.h"
#import <WebKit/WebKit.h>
#import <KVOController/KVOController.h>
#import <WebViewJavascriptBridge/WKWebViewJavascriptBridge.h>
#import "SCViewRouterManager.h"
#import <OpenUDID/OpenUDID.h>

#import "SCSelectBuildingViewController.h"
#import "SCUpdateOwnerController.h"


// 清除WKWebView键盘工具栏使用
@interface SCNoInputAccessoryView : NSObject
@end
@implementation SCNoInputAccessoryView
- (id)inputAccessoryView {
    return nil;
}
@end

@interface SCBaseWebViewController () <WKNavigationDelegate, WKUIDelegate>

// kvo观察者第三方
@property (nonatomic, strong) FBKVOController *KVOController;
// OC与JS交互桥
@property (nonatomic, strong) WKWebViewJavascriptBridge *bridge;
// webview
@property (nonatomic, strong) WKWebView *wkWebView;
// 进度条
@property (nonatomic, strong) UIProgressView *progressView;

// 返回按钮
@property (nonatomic, strong) UIButton *backButton;
// 关闭按钮
@property (nonatomic, strong) UIButton *closeButton;
// 设置全局变量，修改frame，防止出现标题偏移问题
@property (nonatomic, strong)  UIView *leftNavView;

// 当前页面页码，默认-1,只有调用桥_h5_page_index才设置参数
// 如果参数是0，点击返回时直接关闭页面
@property (assign, nonatomic) NSInteger curIndex;

/// 系统返回操作是否有用
@property (assign, nonatomic) BOOL isBackH5Handler;

@end

@implementation SCBaseWebViewController

+ (void)load {
    [SCViewRouterManager registerVCWithURL:SCRouterBaseWebVCUrl vcHandler:^UIViewController *(NSDictionary *routerParameters) {
        SCBaseWebViewController *vc = [[SCBaseWebViewController alloc] initWithNibName:[SCBaseWebViewController sc_className] bundle:nil];
        NSString *url = routerParameters[SCRouterParameterUserInfo][SCRouterParameterUerInfoURLString];
        NSDictionary *userInfoDic = routerParameters[SCRouterParameterUserInfo];
        if ([userInfoDic isKindOfClass:[NSDictionary class]]) {
            SCViewRouterExtra *extraObject = userInfoDic[SCRouterParameterUerInfoExtraObject];
            NSString *detailId = extraObject.detailId;
            if (extraObject.sendType && detailId.length) {
                // 说明是通知
                if ([NSString isValid:detailId]) {
                    if ([url containsString:@"?"]) {
                        url = [NSString stringWithFormat:@"%@&noticeId=%@&sendType=%@",url,detailId,extraObject.sendType];
                    } else {
                        url = [NSString stringWithFormat:@"%@?noticeId=%@&sendType=%@",url,detailId,extraObject.sendType];
                    }
                }
            }
            
            if (extraObject.noToken) {
                //路由跳转拼接的url中，如果noToken存在也要带上
                if ([url containsString:@"?"]) {
                    url = [NSString stringWithFormat:@"%@&noToken=%@", url, extraObject.noToken];
                } else {
                    url = [NSString stringWithFormat:@"%@?noToken=%@", url, extraObject.noToken];
                }
            }
            
        }
        
        vc.urlString = url;
        return vc;
    }];
}

//需要统一拼接参数
- (void)shouldJointParamsInline {
    
    NSString *url = self.urlString;
    //对拼接参数进行统一处理
    if ([NSString isValid:url]) {
        // 评上参数
        if ([url containsString:@"?"]) { //如果url中有?，不再拼接其它参数
            NSString *urlStr = [NSString stringWithFormat:@"%@&%@",url,[self getSplitJointParams]];
            self.urlString = urlStr;
        }
        else if ([url hasPrefix:@"http"]) {
            // 是否http开头
            NSString *urlStr = [NSString stringWithFormat:@"%@?%@",url,[self getSplitJointParams]];
            self.urlString = urlStr;
        } else {
            NSString *urlStr = [NSString stringWithFormat:@"%@/%@?%@",kConfigBaseUrl(SCURLTypeWeb),url,[self getSplitJointParams]];
            self.urlString = urlStr;
        }
    }
    SCLog(@"url=%@", self.urlString);
}

//获取拼接参数
- (NSString *)getSplitJointParams {
    NSString *tokenStr = [SCUser currentLoggedInUser].token;
    SCUser *user = [SCUser currentLoggedInUser];
    return [NSString stringWithFormat:@"token=%@&companyCode=%@&version=%@&defCommunityId=%@&mobileType=%@&mobileName=%@&mobileVersion=%@&appVersion=%@&regionId=%@&mobileNo=%@",ISNULL(tokenStr),kCompanyCode,kAPIVersion, ISNULL(user.communityId),kMobiletype,[UIDeviceHardware platformString],[UIDevice currentDevice].systemVersion,AppVersion,ISNULL(user.selOrgId),[OpenUDID value]];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 注意，设置参数为-1,默认不标记页码
    self.curIndex = -1;
    
    [self setNavigationButton];
    [self setupProgressView];
    [self setupWKWebView];
    
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.bridge) {
        [self.bridge setWebViewDelegate:self];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.bridge setWebViewDelegate:nil];
}

///  加载H5页面
- (void)loadWebRequestServer {
    
    if (self.needJointParams) { //统一拼接参数
        [self shouldJointParamsInline];
    }
    
    NSString *baseUrlString = self.urlString;
    if ([[baseUrlString trim] length] > 0) {
        //url encode编码
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored"-Wdeprecated-declarations"
        baseUrlString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,(CFStringRef)baseUrlString,(CFStringRef)@"!$&'()*+,-./:;=?@_~%#[]",NULL,kCFStringEncodingUTF8));
        #pragma clang diagnostic pop
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:baseUrlString] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
        [self.wkWebView loadRequest:request];
    } else {
        self.isDirectClose = NO;
        [SVProgressHUD showErrorWithStatus:@"网页地址为空"];
    }
}

// 注册桥
- (void)registerHandler {
    @weakify(self)
    // 设置导航栏标题
    [_bridge registerHandler:@"_app_setTitle" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self);
        if ([data isKindOfClass:[NSString class]]) {
            self.title = (NSString *)data;
            return ;
        }
        if (data) {
            self.title = [NSString stringWithFormat:@"%@",data];
        }
    }];
    // 弹框H5是否调用
    [self.bridge registerHandler:@"_app_init_call" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self);
        self.isBackH5Handler = YES;
    }];
    // 弹框H5是否调用
    [self.bridge registerHandler:@"_app_goback_init" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self);
        if ([data isKindOfClass:[NSNumber class]]) {
            self.isCallHanderBack = [data boolValue];
        }
    }];
    // 弹框事件
    [self.bridge registerHandler:@"_app_showdialog" handler:^(id data, WVJBResponseCallback responseCallback) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            // 1.警告框 2.确认框（两个按钮）
            NSInteger type = [data[@"type"] integerValue];
            // 弹框展示内容
            NSString *content = ISNULL(data[@"content"]);
            // 按钮数组，从左到右 确定按钮、取消按钮
            NSArray *buttonMsgArray = data[@"buttonMsg"];
            // 确认事件定义, goback执行返回；close执行关闭
            NSString *confirmName = data[@"btnFun"];
            
            NSString *sureTitle = @"确定";
            NSString *cancelTitle = (type == 2 ? @"取消" : @"确定");
            
            if ([buttonMsgArray isKindOfClass:[NSArray class]] && buttonMsgArray.count > 0) {
                
                // 确定按钮文案
                NSString *buttonMsgF = buttonMsgArray.firstObject;
                if ([buttonMsgF isKindOfClass:[NSString class]] && buttonMsgF.length > 0) {
                    sureTitle = buttonMsgF;
                }
                
                // 取消按钮文案
                if (buttonMsgArray.count > 1) {
                    NSString *buttonMsgS = buttonMsgArray[1];
                    if ([buttonMsgS isKindOfClass:[NSString class]] && buttonMsgS.length > 0) {
                        cancelTitle = buttonMsgS;
                    }
                }
            }
            
            UIAlertController * alertController = [UIAlertController alertControllerWithTitle:nil message:content preferredStyle:UIAlertControllerStyleAlert];
            
            if (type == 2) { // 确认按钮
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:sureTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    if ([confirmName isEqualToString:@"goback"]) { // 返回
                        if ([self.wkWebView canGoBack]) {
                            [self.wkWebView goBack];
                            return;
                        }
                        [self.navigationController popViewControllerAnimated:YES];
                    } else if ([confirmName isEqualToString:@"close"]) { // 关闭
                        [self.navigationController popViewControllerAnimated:YES];
                    }
                }];
                [alertController addAction:okAction];
            }
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleDefault handler:nil];
            [alertController addAction:cancelAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
    }];
    //关闭webView并回退到上一页
    [self.bridge registerHandler:@"_app_close_h5" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self);
        NSString *tips = (NSString *)data;
        //如果有需要原生提示的语句，原生就能弹出一个弹框，供用户阅读并关闭
        if (tips && [tips isKindOfClass:[NSString class]] && tips.length > 0) {
            UIAlertController *alertView = [UIAlertController alertControllerWithTitle:nil message:tips preferredStyle:UIAlertControllerStyleAlert];
            [alertView addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self.navigationController popViewControllerAnimated:YES];
            }]];
            [self presentViewController:alertView animated:YES completion:nil];
        } else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }];
    
    
    /// 通知详情点击签到按钮
    [self.bridge registerHandler:@"app_refresh_notice_list" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self);
        if (self.callHanderBlock) {
            self.callHanderBlock(nil);
        }
    }];
    
    //显示关于按钮
    [self.bridge registerHandler:@"show_nav_about" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self);
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSNumber *show = data[@"show"];
            NSArray *titles = data[@"titles"];
            NSArray *icons = data[@"icons"];
            if (show.boolValue) {
                if (titles && [titles isKindOfClass:[NSArray<NSString *> class]] && titles.count > 0) {
                    
                    NSMutableArray *items = [NSMutableArray arrayWithCapacity:1];
                    for (NSInteger i = 0; i < titles.count; i++) {
                        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:titles[i] style:UIBarButtonItemStylePlain target:self action:@selector(showNavAboutAction:)];
                        item.tag = i;
                        [items addObject:item];
                    }
                    
                    self.navigationItem.rightBarButtonItems = items;
                    
                } else if (icons && icons.count > 0) {
                    NSMutableArray *items = [NSMutableArray array];
                    for (NSUInteger i = 0; i < icons.count; i++) {
                        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:icons[i]] style:UIBarButtonItemStylePlain target:self action:@selector(showNavAboutAction:)];
                        item.tag = i;
                        [items addObject:item];
                    }
                    self.navigationItem.rightBarButtonItems = items;
                    
                } else {
                    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"help_icon_top"] style:UIBarButtonItemStylePlain target:self action:@selector(showNavAboutAction:)];
                    item.tag = 0;
                    self.navigationItem.rightBarButtonItem = item;
                }
            } else {
                self.navigationItem.rightBarButtonItem = nil;
                self.navigationItem.rightBarButtonItems = nil;
            }
        }
    }];
    
    // 选择地址
    [self.bridge registerHandler:@"_app_choose_roomId" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self)
        [self chooseAddressComplete:^(SCAddress *address) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setValue:address.roomId forKey:@"roomId"];
            [dict setValue:address.description forKey:@"address"];
            responseCallback(dict.mj_JSONString);
        }];
    }];
    
    // 新增业主
    [self.bridge registerHandler:@"_app_new_user" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self)
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSString *roomId = [NSString stringWithFormat:@"%@", data[@"roomId"]];
            NSString *address = data[@"address"];
            [self actionForAddNewUserWithRoomId:roomId addressSring:address complete:^(BOOL success) {
                NSMutableDictionary *dict = [NSMutableDictionary new];
                [dict setValue:(success ? @"1" : @"0") forKey:@"success"];
                responseCallback(dict.mj_JSONString);
            }];
        }
    }];
    
    // 当前项目信息
    [self.bridge registerHandler:@"getCommunityInfo" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSMutableDictionary *response = [NSMutableDictionary dictionary];
        [response setValue:[SCUser currentLoggedInUser].communityId forKey:@"communityId"];
        [response setValue:[SCUser currentLoggedInUser].communityName forKey:@"communityName"];
        responseCallback(response.mj_JSONString);
    }];
    
    // 是否显示返回按钮桥
    [self.bridge registerHandler:@"_app_back_show" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self)
        if ([data isKindOfClass:[NSDictionary class]]) {
            BOOL show = [data[@"show"] boolValue];
            self.backButton.hidden = (!show);
            self.closeButton.frame = CGRectMake(show ? 44 : -15, 0, 44, 44);
        }
    }];
    
    // 判断当前页面页码桥
    [self.bridge registerHandler:@"_h5_page_index" handler:^(id data, WVJBResponseCallback responseCallback) {
        @strongify(self)
        if ([data isKindOfClass:[NSDictionary class]]) {
            self.curIndex = [data[@"index"] integerValue];
        }
    }];
}

// 选择地址
- (void)chooseAddressComplete:(void(^)(SCAddress *address))complete {
    [self.view endEditing:YES];
    SCSelectBuildingViewController *selBuildingVC = [[SCSelectBuildingViewController alloc] initWithNibName:[SCSelectBuildingViewController sc_className] bundle:nil];
    SCBaseNavigationController *nav = [[SCBaseNavigationController alloc] initWithRootViewController:selBuildingVC];
    selBuildingVC.onAddressSelected = complete;
    selBuildingVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:nav animated:YES completion:^{}];
}

/// 新增业主（需要把房号带进去）
- (void)actionForAddNewUserWithRoomId:(NSString *)roomId addressSring:(NSString *)addressString  complete:(void(^)(BOOL success))complete {
    if (roomId.length == 0) {
        [SVProgressHUD showErrorWithStatus:@"请选择房号" duration:2.0 dismiss:nil];
        return;
    }
    
    SCUpdateOwnerController *vc = [[SCUpdateOwnerController alloc] initWithNibName:NSStringFromClass([SCUpdateOwnerController class]) bundle:nil];
    vc.addressSring = addressString;
    vc.roomId = roomId;
    vc.noEditAddress = YES;
    [vc updateOwnerInfoComplete:^(BOOL success) {
        if (complete) {
            complete(success);
        }
    }];
    [self.navigationController pushViewController:vc animated:YES];
}

/**
 按钮响应事件
 */
- (void)showNavAboutAction:(UIBarButtonItem *)item {
    @weakify(self);
    NSDictionary *param = @{
                            @"index":@(item.tag)
                            };
    NSData *paraData = [NSJSONSerialization dataWithJSONObject:param options:NSJSONWritingPrettyPrinted error:nil];
    NSString *paramJSON = [[NSString alloc] initWithData:paraData encoding:NSUTF8StringEncoding];;
    [self.bridge callHandler:@"about_action" data:paramJSON responseCallback:^(id responseData) {
        @strongify(self);
        if ([responseData isKindOfClass:[NSDictionary class]]) {
            NSString *url = responseData[@"url"];
            SCBaseWebViewController *viewController = [[SCBaseWebViewController alloc] initWithNibName:@"SCBaseWebViewController" bundle:nil];
            viewController.urlString = url;
            viewController.needJointParams = YES;
            [self.navigationController pushViewController:viewController animated:YES];
        }
    }];
}

// 进度条的观察者
- (void)setUpKVOMethods {
    self.KVOController = [FBKVOController controllerWithObserver:self];
    @weakify(self)
    // 监听进度条
    [self.KVOController observe:self.wkWebView keyPath:@"estimatedProgress" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew block:^(SCBaseWebViewController *vc, WKWebView *wkWebView, NSDictionary *change) {
        @strongify(self)
        CGFloat progress = [[change objectForKey:NSKeyValueChangeNewKey] doubleValue];
        if (progress == 1.0) {
            self.progressView.hidden = YES;
            [self.progressView setProgress:0 animated:NO];
        } else {
            self.progressView.hidden = NO;
            [self.progressView setProgress:progress animated:YES];
        }
    }];
    
    // 监听canGoBack,关闭在代理方法后有时会改变
    [self.KVOController observe:self.wkWebView keyPath:@"canGoBack" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew block:^(SCBaseWebViewController *vc, WKWebView *wkWebView, NSDictionary *change) {
        @strongify(self)
        BOOL goBack = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        self.closeButton.hidden = !goBack;
        if (self.closeButton.hidden) {
            self.leftNavView.frame = CGRectMake(0, 0, 44, 44);
        } else {
            self.leftNavView.frame = CGRectMake(0, 0, 88, 44);
        }
    }];
    // 监听title
    [self.KVOController observe:self.wkWebView keyPath:@"title" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        @strongify(self)
        if (!self.title || self.title.length == 0) {
            self.navigationItem.title = self.wkWebView.title;
        }
    }];
    
    [self.KVOController observe:self.wkWebView keyPath:@"URL" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        @strongify(self)
        // url修改，isCallHanderBack参数修改为NO；
        // 解决bug:【集测】【产品】【用户端APP】【问卷调查】问卷调查，先进入调查详情选择某一项，不保存退出，会有未保存的提醒，调查列表页，再返回，还是有提醒；iOS上是这样，安卓没有提醒。
        self.isBackH5Handler = NO;
    }];
}

#pragma mark - private action
// 设置WKWebView
- (void)setupWKWebView {
    self.wkWebView = [[WKWebView alloc] initWithFrame:CGRectZero];
    self.wkWebView.backgroundColor = SC_BACKGROUD_COLOR;
    self.wkWebView.scrollView.showsVerticalScrollIndicator = NO;
    self.wkWebView.navigationDelegate = self;
    self.wkWebView.UIDelegate = self;
    // 删除顶部键盘工具栏
    [self removeInputAccessoryViewFromWKWebView:self.wkWebView];
    // 将WKWebView添加到视图
    [self.view insertSubview:self.wkWebView belowSubview:self.progressView];
    [self.wkWebView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    //载入网页
    [self loadWebRequestServer];
    
    [WKWebViewJavascriptBridge enableLogging];
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.wkWebView];
    [self.bridge setWebViewDelegate:self];
    
    [self setUpKVOMethods];
    [self registerHandler];
}

// 设置进度条
- (void)setupProgressView {
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0.0, 0.0, SCREEN_WIDTH, 0.0)];
    self.progressView.tintColor = SC_TEXT_GREEN_COLOR;
    self.progressView.trackTintColor = [UIColor whiteColor];
    [self.view addSubview:self.progressView];
}

// 设置导航条
- (void)setNavigationButton {
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 88, 44)];
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.backButton = backButton;
    [backButton setImage:[UIImage imageNamed:@"nav_back"] forState:UIControlStateNormal];
    [backButton sizeToFit];
    [backButton setTitle:@"返回" forState:UIControlStateNormal];
    [backButton.titleLabel setFont:[UIFont systemFontOfSize:16]];
    backButton.contentEdgeInsets = UIEdgeInsetsMake(0, -20, 0, 0);
    backButton.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    [backButton addTarget:self action:@selector(getBackAction) forControlEvents:UIControlEventTouchUpInside];
    backButton.frame = CGRectMake(0, 0, 44, 44);
    [leftView addSubview:backButton];
    
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [self.closeButton.titleLabel setFont:[UIFont systemFontOfSize:16]];
    self.closeButton.frame =CGRectMake(44, 0, 44, 44);
    [self.closeButton addTarget:self action:@selector(closeCurrentViewAction) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.hidden = YES;
    [leftView addSubview:self.closeButton];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftView];
}

// 更改nav按钮的显示
- (void)updateCloseButton {
    if ([self.wkWebView canGoBack]) {
        if (self.closeButton.hidden) {
            self.closeButton.hidden = NO;
            self.leftNavView.frame = CGRectMake(0, 0, 88, 44);
        }
    } else {
        if (!self.closeButton.hidden) {
            self.closeButton.hidden = YES;
            self.leftNavView.frame = CGRectMake(0, 0, 44, 44);
        }
    }
}

// 点击返回按钮事件
- (void)getBackAction {
    if (self.isDirectClose) { //如果直接关闭，则使用_app_h5_goBack桥进行判断（由h5注册该桥），用处如商家入驻页面等
        @weakify(self);
        [self.bridge callHandler:@"_app_h5_goBack" data:nil responseCallback:^(id responseData) {
            @strongify(self);
            if ([responseData boolValue]) { //返回h5的上一页
                if ([self.wkWebView canGoBack]) {
                    [self.wkWebView goBack];
                } else {
                    //关闭webView
                    [self.navigationController popViewControllerAnimated:YES];
                }
            } else { //直接关闭webView
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
    } else if (self.isCallHanderBack || self.isBackH5Handler) { // 实现该方法，调用
        [self.bridge callHandler:@"_h5_goback_cb" data:nil responseCallback:^(id responseData) {
            // 是否阻断返回
            BOOL state = [responseData[@"state"] boolValue];
            // 阻断
            if (state) {
                // 需要回调
            } else {
                if ([self.wkWebView canGoBack]) {
                    [self.wkWebView goBack];
                    return;
                }
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
    } else {
        
        // 如果页码是0，点击返回，直接退出H5
        if (self.curIndex == 0) {
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        
        if ([self.wkWebView canGoBack]) {
            [self.wkWebView goBack];
            return;
        }
        [self.navigationController popViewControllerAnimated:YES];
    }
}

// 点击关闭按钮事件
- (void)closeCurrentViewAction {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - WKNavigationDelegate, WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (completionHandler) {
            completionHandler();
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(nonnull NSString *)message initiatedByFrame:(nonnull WKFrameInfo *)frame completionHandler:(nonnull void (^)(BOOL))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (completionHandler) {
            completionHandler(NO);
        }
    }])];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completionHandler) {
            completionHandler(YES);
        }
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.wkWebView.scrollView.mj_header endRefreshing];
    [self updateCloseButton];
}

// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    self.isDirectClose = NO; //如果页面加载失败，点击返回按钮，不与H5进行交互
    [self.wkWebView.scrollView.mj_header endRefreshing];
    [self updateCloseButton];
}

// 处理网页回调
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    [webView shouldStartLoadWithRequest:navigationAction.request];
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 需要实现，否则如果链接中包含target= _blank将不能跳转
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
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

// 删除顶部键盘工具栏
- (void)removeInputAccessoryViewFromWKWebView:(WKWebView *)webView {
    
    UIView *targetView;
    for (UIView *view in webView.scrollView.subviews) {
        if([[view.class description] hasPrefix:@"WKContent"]) {
            targetView = view;
        }
    }
    
    if (!targetView) {
        return;
    }

    NSString *noInputAccessoryViewClassName = [NSString stringWithFormat:@"%@_NoInputAccessoryView", targetView.class.superclass];
    Class newClass = NSClassFromString(noInputAccessoryViewClassName);
    if(newClass == nil) {
        newClass = objc_allocateClassPair(targetView.class, [noInputAccessoryViewClassName cStringUsingEncoding:NSASCIIStringEncoding], 0);
        if(!newClass) {
            return;
        }
        
        Method method = class_getInstanceMethod([SCNoInputAccessoryView class], @selector(inputAccessoryView));
        class_addMethod(newClass, @selector(inputAccessoryView), method_getImplementation(method), method_getTypeEncoding(method));
        objc_registerClassPair(newClass);
    }
    object_setClass(targetView, newClass);
}

@end
