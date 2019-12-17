//
//  SCScanViewController.m
//  Butler
//
//  Created by Linkou Bian on 8/25/14.
//  Copyright (c) 2014 UAMA Inc. All rights reserved.
//

#import "SCScanInputViewController.h"

/// VC
#import "SCBaseNavigationController.h"
#import "SCPassResultViewController.h"
#import "SCExpUnAcceptViewController.h"
#import "SCExpAcceptViewController.h"
#import "SCExpMultiSignViewController.h"
#import "SCManualBarCodeViewController.h"
#import "SCActivityDetailController.h"
#import "SCDepositDetailController.h"
#import "SCDeviceAccountItemViewController.h"
#import "SCCarParkDetailViewController.h"
#import "SCUniversalCodeResultController.h"
#import "SCOfflineActivitySignInController.h"
#import "SCWebViewController.h"
#import "SCCodeInputViewController.h"
#import "SCNewActivitySignViewController.h"
#import "SCWriteOffOrderDetailController.h"
#import "SCVisitorDetailController.h"
#import "SCofflineActivitySignUpDetail.h"

/// View
#import "SCScanBottomView.h"
#import "SCScanner.h"

/// Model
#import "SCExpress.h"
#import "SCUniversalCodeResult.h"

// API
#import "SCVisitorPasscodeVerifyAPI.h"
#import "SCFetchExpressInfoAPI.h"
#import "SCUniversalCodeResultAPI.h"

/// other
#import "WESoundHelper.h"
#import "SCHomeScanQrcodeHelper.h"
#import "SCDeviceAuthManager.h"
#import "SCOfflineActivityMananger.h"
#import "SCQrCodeDecryptHelper.h"
#import "SCDeviceAccountManager.h"

#import "SCGoodsAccessAddController.h"
#import "SCGoodsAccessDetailAPI.h"

// 物品借用
#import "SCGoodsBorrowLendQRCodeAPI.h"
#import "SCOwnerBorrowViewController.h"
#import "SCGoodsBorrowListModel.h"
#import "SCGoodsBorrowGiveBackDoneController.h"
#import "SCGoodsBorrowGiveBackController.h"

@interface SCScanInputViewController ()<AVCaptureMetadataOutputObjectsDelegate>

@property (strong, nonatomic) AVCaptureDevice * device;
@property (strong, nonatomic) AVCaptureDeviceInput * input;

@property (strong, nonatomic) AVCaptureMetadataOutput * output;
@property (strong, nonatomic) AVCaptureSession * session;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer * preview;

// 底部按钮视图
@property (nonatomic, strong) SCScanBottomView *bottomView;

@property (nonatomic, strong) SCScanner *scanView;
@property (nonatomic, strong) UIView *maskView;
@property (nonatomic, strong) UIImageView *scanFrameView;

@property (nonatomic, assign) CGSize transparentSize;
@property (nonatomic, assign) SCSanSourceType scanType;
/// 闪光灯是否打开
@property (nonatomic, assign) BOOL torchFlashed;
/// 手电按钮设置为全局变量，主要是弹出alert/跳转到下一页的时候，会自动关掉；然后就无法再次打开，所以全局记录一下
@property (nonatomic, strong) UIButton  *flashBtn;

@property (nonatomic, strong) SCHomeScanQrcodeHelper *scanHelper;

@end

@implementation SCScanInputViewController

- (SCHomeScanQrcodeHelper *)scanHelper {
    if (!_scanHelper) {
        _scanHelper = [[SCHomeScanQrcodeHelper alloc] init];
    }
    return _scanHelper;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:NO];
    self.transparentSize = CGSizeMake(239, 240);
    self.scanType = SCSanSourceTypeQR;
    [self fetchAuthorizationOfCamera];
    [self setUpUIWithTransparentSize:self.transparentSize];
    
    /// 监测后台切换到前台的通知，用来重置手电按钮状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetTorchFlash) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)fetchAuthorizationOfCamera {
    @weakify(self)
    [SCDeviceAuthManager fetchAuthorizationOfCameraAuthorized:^{
        @strongify(self)
        [self initScanComponent];
    } waitAuthorize:^{
        @strongify(self)
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC);
        dispatch_after(delay, dispatch_get_main_queue(), ^{
            [self setUpUIWithTransparentSize:self.transparentSize];
            [self initScanComponent];
        });
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self.session startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
    [self.session beginConfiguration];
    [self.device lockForConfiguration:nil];
    if (self.device.torchMode == AVCaptureTorchModeOn) {
        [self.device setTorchMode:AVCaptureTorchModeOff];
        [self.device setFlashMode:AVCaptureFlashModeOff];
    }
    [self.device unlockForConfiguration];
    [self.session commitConfiguration];
    /// 页面将要消失的时候 重置手电按钮状态
    [self resetTorchFlash];
}

- (void)initScanComponent  {
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    // Input
    _input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:&error];
    
    if (error) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告"
                                                                                 message:[error localizedDescription]
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDestructive handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:
                                    UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        _output = [[AVCaptureMetadataOutput alloc] init];
        NSLog(@"------支持种类 = %@------",[_output availableMetadataObjectTypes]);
        [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        
        // Session
        _session = [[AVCaptureSession alloc] init];
        [_session setSessionPreset:AVCaptureSessionPresetHigh];
        if ([_session canAddInput:self.input]) {
            [_session addInput:self.input];
        }
        if ([_session canAddOutput:self.output]) {
            [_session addOutput:self.output];
        }
        _output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode39Code];
        [_output setRectOfInterest:[self scanRectWithSize:CGSizeMake(239, 181)]];
        
        // Preview
        _preview =[AVCaptureVideoPreviewLayer layerWithSession:_session];
        _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _preview.frame =self.view.layer.bounds;
        [self.view.layer insertSublayer:_preview atIndex:0];
        [_session startRunning];
    }
}

// 设置UI
- (void)setUpUIWithTransparentSize:(CGSize)size {
    CGRect screenRect = [UIScreen mainScreen].bounds;
    if (self.scanView == nil) {
        self.scanView = [[SCScanner alloc] initWithFrame:screenRect];
    }
    self.scanView.scanType = self.scanType;
    self.scanView.transparentArea = size;
    self.scanView.backgroundColor = [UIColor clearColor];
    self.scanView.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    [self.view addSubview:self.scanView];
    if (self.maskView == nil) {
        self.maskView = [[UIView alloc] initWithFrame:screenRect];
    }
    [self.maskView setBackgroundColor:[UIColor clearColor]];

    CGFloat kTopSpace = UI_IS_IPHONEX() ? 54.0f : 30.0f;
    // 返回按钮
    UIButton *backBtn = [[UIButton alloc] init];
    [backBtn addTarget:self action:@selector(backBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
    [backBtn setImage:[UIImage imageNamed:@"code_scan_back"] forState:UIControlStateNormal];
    backBtn.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self.maskView addSubview:backBtn];
    [backBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(kTopSpace);
        make.leading.mas_equalTo(15 * SCREEN_WIDTH/320.0);
        make.size.mas_equalTo(CGSizeMake(35.0, 35.0));
    }];
    // 闪光灯按钮
    self.flashBtn = [[UIButton alloc] init];
    [self.flashBtn setImage:[UIImage imageNamed:@"lamp_off"] forState:UIControlStateNormal];
    [self.flashBtn addTarget:self action:@selector(flashBtnAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.maskView addSubview:self.flashBtn];
    [self.flashBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(kTopSpace);
        make.trailing.mas_equalTo(-(15 * SCREEN_WIDTH/320.0));
        make.size.mas_equalTo(CGSizeMake(35.0, 35.0));
    }];

    if (!_bottomView) {
        _bottomView = [SCScanBottomView loadScanBottomView];
    }
    [self.maskView addSubview:self.bottomView];
    [self.bottomView setFrame:CGRectMake(0, SCREEN_HEIGHT-20-SCHomeIndicatorHeight-60, SCREEN_WIDTH, 60)];
    @weakify(self)
    self.bottomView.itemSeletced = ^(NSInteger index, NSString *itemTitle) {
        @strongify(self)
        if (index == 0) {
            [self qrImageViewClicked];
        } else if (index == 1) {
            [self barImageViewClicked];
        } else {
            [self onInputAction];
        }
        /// 统计
        [SCTrackManager trackEvent:kScanTabClick attributes:@{@"tabName":itemTitle}];
    };
    
    if (self.scanFrameView == nil) {
        self.scanFrameView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"code_scannner"]];
    }
    [self.scanFrameView setFrame:CGRectMake(self.view.center.x - 120, self.view.center.y - 120, 240, 240)];
    [self.maskView addSubview:self.scanFrameView];
    [self.view addSubview:self.maskView];
}


/// 重置手电按钮状态
- (void)resetTorchFlash {
    if (self.torchFlashed) {
        self.torchFlashed = NO;
        [self.flashBtn setImage:[UIImage imageNamed:@"lamp_off"] forState:UIControlStateNormal];
    }
}

// 返回按钮事件
- (void)backBtnPressed:(UIButton *)button {
    if (self.navigationController.viewControllers.count > 1) {
        // 说明页面是pushViewController出来的
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        // 说明页面是presentViewController出来的
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// 闪光灯按钮事件
- (void)flashBtnAction:(UIButton *)button {
    if (!self.torchFlashed) {
        //打开闪光灯
        if ([self.device hasTorch]&&[self.device hasFlash]) {
            if (self.device.torchMode == AVCaptureTorchModeOff) {
                [self.session beginConfiguration];
                [self.device lockForConfiguration:nil];
                [self.device setTorchMode:AVCaptureTorchModeOn];
                [self.device setFlashMode:AVCaptureFlashModeOn];
                [self.device unlockForConfiguration];
                [self.session commitConfiguration];
                self.torchFlashed = !self.torchFlashed;
            }
            /// 统计
            [SCTrackManager trackEvent:kScanFlashlightClick];
        } else {
            [SVProgressHUD showErrorWithStatus:@"您的设备无闪光灯" duration:1.0 dismiss:nil];
        }
    } else {
        //关闭闪光灯
        [self.session beginConfiguration];
        [self.device lockForConfiguration:nil];
        if (self.device.torchMode == AVCaptureTorchModeOn) {
            [self.device setTorchMode:AVCaptureTorchModeOff];
            [self.device setFlashMode:AVCaptureFlashModeOff];
            self.torchFlashed = !self.torchFlashed;
        }
        [self.device unlockForConfiguration];
        [self.session commitConfiguration];
    }
    
    NSString *imageName = self.torchFlashed ? @"lamp_on" : @"lamp_off";
    [button setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
}

/// 二维码按钮点击事件
- (void)qrImageViewClicked {
    self.transparentSize = CGSizeMake(239, 240);
    self.scanType = SCSanSourceTypeQR;
    self.scanView.transparentArea = self.transparentSize;
    self.scanView.scanType = self.scanType;
    
    [UIView animateWithDuration:0.2 animations:^{
        [self.scanFrameView setFrame:CGRectMake(self.view.center.x - 120, self.view.center.y - 120, 240, 240)];
        [self.scanView setNeedsLayout];
        [self.scanView setNeedsDisplay];
    }];
    NSLog(@"------可扫描区域 = %@------",[NSString stringWithFormat:@"%@",NSStringFromCGRect(_output.rectOfInterest)]);
}

/// 快递单按钮点击事件
- (void)barImageViewClicked {
    self.transparentSize = CGSizeMake(239, 181);
    self.scanType = SCSanSourceTypeBar;
    self.scanView.transparentArea = self.transparentSize;
    self.scanView.scanType = self.scanType;
    [UIView animateWithDuration:0.2 animations:^{
        [self.scanFrameView setFrame:CGRectMake(self.view.center.x - 120, self.view.center.y - 90, 240, 180)];
        [self.scanView setNeedsLayout];
        [self.scanView setNeedsDisplay];
    }];
    NSLog(@"------可扫描区域 = %@------",[NSString stringWithFormat:@"%@",NSStringFromCGRect(_output.rectOfInterest)]);
}

/// 条码输入入口
- (void)onInputAction {
    SCCodeInputViewController *vc = [[SCCodeInputViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (CGRect)scanRectWithSize:(CGSize)size {
    CGRect screenRect = [UIScreen mainScreen].bounds;
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat scanWidth = size.width;
    CGFloat scanHeight = size.height;
    CGFloat scanOriginX = self.view.center.x - scanWidth/2;
    CGFloat scanOriginY = self.view.center.y - scanHeight/2;
    CGRect scanRect = CGRectMake(scanOriginY/screenHeight, scanOriginX/screenWidth, scanHeight/screenHeight, scanWidth/screenWidth);
    return scanRect;
}


#pragma mark AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSString *stringValue;
    
    if ([metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        stringValue = metadataObject.stringValue;
        NSString *typeStr = metadataObject.type;
        if ([typeStr isEqualToString:AVMetadataObjectTypeQRCode]) {
            if (self.scanType == SCSanSourceTypeQR) {
                [self.session stopRunning];
                NSLog(@"stringValue =  %@",stringValue);
                [self onScanned:stringValue];
            }
        } else {
            if (self.scanType == SCSanSourceTypeBar) {
                [self.session stopRunning];
                NSLog(@"stringValue =  %@",stringValue);
                [self onScanned:stringValue];
            }
        }
    }
}

#pragma mark - Private
// 扫描结束后处理
- (void)onScanned:(NSString *)result {
    /// 重新设置手电按钮
    [self resetTorchFlash];
    
    [WESoundHelper playSoundFromFile:@"beep.wav" fromBundle:[NSBundle mainBundle] asAlert:YES];
    switch (self.scanType) {
        case SCSanSourceTypeQR:
            [self dispatchQRCode:result];
            break;
        case SCSanSourceTypeBar:
            [self dispatchExpressLogResult:result];
            break;
        default:
            break;
    }
}

// 条码输入二维码进行快递录入
- (void)dispatchExpressLogResult:(NSString *)code {
    AFNetworkReachabilityStatus status = [[AFNetworkReachabilityManager sharedManager] networkReachabilityStatus];
    if (status == AFNetworkReachabilityStatusNotReachable || status == AFNetworkReachabilityStatusUnknown) {
        @weakify(self)
        [SVProgressHUD showErrorWithStatus:@"网络失去连接" duration:1.0 dismiss:^{
            @strongify(self)
            [self.session startRunning];
        }];
    } else {
        [MobClick event:@"Home_Scan_ExpressBill"];
        [self jumpToManualCodeVC:code];
    }
}

// 根据二维码类型进行不同处理
- (void)dispatchQRCode:(NSString *)code {
    [MobClick event:@"Home_Scan_QRCode"];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", kUrlRegular];
    BOOL isMatch = [pred evaluateWithObject:code];
    if (isMatch) {
        //url类型的二维码处理方法
        [self hasPrefixURLQrCodeHandel:code];
    } else if ([SCQrCodeDecryptHelper judgeWithqrCode:code]) {
        // 如果是以uama_开头，则说明是内部新规则的二维码
        [self hasPrefixUamaQrCodeHandel:code];
    } else if ([code hasPrefix:kUniversalQrCodePrefix]) {
        // 如果是以UM_开头，则说明是新万能二维码
        [self dispatchUniversalCodeResult:code];
    } else {
        // 旧的二维码处理
        [self oldQrcodeHandle:code];
    }
}

// url的二维码处理方法
- (void)hasPrefixURLQrCodeHandel:(NSString *)code {
    // 是url类型的二维码
    if (([code rangeOfString:@"forButler"].location != NSNotFound) && ([code rangeOfString:@"idCode"].location != NSNotFound)) {
        //说明是南京东方的活动二维码
        NSString *vaule = [SCCommonHelper getParamByName:@"idCode" URLString:code];
        if (vaule.length > 0) {
            // 进入活动签到
            SCNewActivitySignViewController *activityVC = [[SCNewActivitySignViewController alloc] initWithNibName:[SCNewActivitySignViewController sc_className] bundle:nil];
            activityVC.qrcode = vaule;
            [self.navigationController pushViewController:activityVC animated:YES];
        } else {
            [SVProgressHUD showErrorWithStatus:@"未知类型二维码" duration:1.0 dismiss:^{
                [self.session startRunning];
            }];
        }
    } else {
        /// 其他url处理
        [self alertForPrefixURLQrCodeHandel:code];
    }
}

/// 弹出提示框
- (void)alertForPrefixURLQrCodeHandel:(NSString *)code {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:code
                                                            preferredStyle:UIAlertControllerStyleAlert] ;
    
    // 取消
    @weakify(self);
    UIAlertAction  *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              @strongify(self);
                                                              [self.session startRunning];
                                                          }];
    // 确认
    
    UIAlertAction  *confirmAction = [UIAlertAction actionWithTitle:@"打开链接" style:UIAlertActionStyleDefault  handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        /// 延时一下
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SCWebViewController *controller = [[SCWebViewController alloc] initWithURL:[NSURL URLWithString:[code formatEncodeURLString]]];
            [self.navigationController pushViewController:controller animated:YES];
        });
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 新规则的二维码处理
- (void)hasPrefixUamaQrCodeHandel:(NSString *)code {
    @weakify(self)
    
    [SCQrCodeDecryptHelper decryptWithQrCode:code success:^(SCQRCodeType type, NSString *acode) {
        @strongify(self)
        switch (type) {
            case SCQRCodeTypeUniversal: {
                // 万能二维码
                [self dispatchUniversalCodeResult:code];
            } break;
                
            case SCQRCodeTypePatrolManager: {
                // 巡查二维码
                [self dispatchPatorlManagerScanResult:acode];
            } break;
                
            case SCQRCodeTypePanelMeter: {
                // 抄表二维码
                [self dispatchPanelMeterScanResult:acode];
            } break;
                
            case SCQRCodeTypeWriteOffOrder:
                /// 订单核销
                [self dispatchWriteOffOrderScanResult:code];
                break;
                
            default:
                [SVProgressHUD showErrorWithStatus:@"未知类型二维码" duration:1.0 dismiss:^{
                    [self.session startRunning];
                }];
                break;
        }
    } failure:^(NSError *error) {
        [SVProgressHUD showErrorWithStatus:@"未知类型二维码" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }];
}

/// 旧规则的二维码处理方法
- (void)oldQrcodeHandle:(NSString *)code {
    SCQRCodeType type = [SCQrCodeDecryptHelper currentQRCodeType:code];
    switch (type) {
        case SCQRCodeTypeUnknown: {
            [SVProgressHUD showErrorWithStatus:@"未知类型二维码" duration:1.0 dismiss:^{
                [self.session startRunning];
            }];
        } break;
        case SCQRCodeTypePassport:
            [self dispatchPassportScanResult:code];
            break;
        case SCQRCodeTypeExpress:
            [self dispatchExpressScanResult:code];
            break;
        case SCQRCodeTypeActivitySignIn:
            [self dispatchActivitySignInScanResult:code];
            break;
        case SCQRCodeTypeDeposit:
            [self dispatchDepositScanResult:code];
            break;
        case SCQRCodeTypeDevice:{
            if ([code rangeOfString:@"∝"].location != NSNotFound) {
                NSRange range = [code rangeOfString:@"∝"];
                code = [code substringToIndex:range.location];
            }
            if ([[code trim] length] > 9) {
                code = [code substringToIndex:6];
            }
            [self dispatchDeviceScanResult:code];
        } break;
            
        case SCQRCodeTypeCarShare: {
            [self dispatchCarSharedScanResult:code];
        } break;
            
        case SCQRCodeTypeOfflineActivity: {
            // 热门活动二维码，不支持之前5开头的老的二维码
            [self dispatchOfflineActivityResult:code];
        } break;
            
        case SCQRCodeTypeGoodsAccess: {
            // 物品出门
            [self dispatchGoodsAccessScanResult:code];
        } break;
            
        case SCQRCodeTypeGoodsBorrow:{
            // 物品借用
            [self dispatchGoodsBorrowScanResult:code];
        } break;
            
        default:
            break;
    }
}

// 处理热门活动二维码
- (void)dispatchOfflineActivityResult:(NSString *)code {
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeHotActivity]) {
        @weakify(self)
        [SVProgressHUD show];
        // 先根据二维码获取下数据，然后根据返回情况进行处理
        [SCOfflineActivityMananger fetchOfflineActivityWithQrcode:code success:^(SCofflineActivitySignUpDetail *detail) {
            @strongify(self)
            // 如果参与人为空，则提示文案
            if (detail.participatorList.count == 0) {
                [SVProgressHUD showErrorWithStatus:@"所有参与人都已签到" duration:2 dismiss:nil];
            } else {
                [SVProgressHUD dismiss];
                SCOfflineActivitySignInController *signinVC = [[SCOfflineActivitySignInController alloc] initWithNibName:NSStringFromClass([SCOfflineActivitySignInController class]) bundle:nil];
                signinVC.detail = detail;
                signinVC.qrcode = code;
                [self.navigationController pushViewController:signinVC animated:YES];
            }
        } failuer:^(NSError *error) {
            [SCAlertHelper handleError:error];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.session startRunning];
            });
        }];
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }
}

// 处理万能二维码
- (void)dispatchUniversalCodeResult:(NSString *)code {
    // 埋点 二维码扫描-成功扫描万能二维码 add by jqb 2018/8/4
    [SCTrackManager trackEvent:kStatusEventQRCodeScanUrlSuccess];
    [SVProgressHUD show];
    SCUniversalCodeResultAPI *api = [[SCUniversalCodeResultAPI alloc] initWithCode:code];
    @weakify(self)
    [api startWithCompletionWithSuccess:^(id responseDataDict) {
        @strongify(self)
        [SVProgressHUD dismiss];
        SCUniversalCodeResult *result = [SCUniversalCodeResult mj_objectWithKeyValues:responseDataDict];
        SCUniversalCodeResultController *resultVC = [[SCUniversalCodeResultController alloc] initWithNibName:[SCUniversalCodeResultController sc_className] bundle:nil];
        resultVC.result = result;
        [self.navigationController pushViewController:resultVC animated:YES];
    } failure:^(NSError *error) {
        @strongify(self)
        [SCAlertHelper handleError:error];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.session startRunning];
        });
    }];
}

// 快递二维码处理
- (void)dispatchExpressScanResult:(NSString *)code {
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeExpRecord]) {
        // 埋点 二维码扫描-成功扫描快递取件码 add jqb 2018/8/4
        [SCTrackManager trackEvent:kStatusEventQRCodeScanExpressSuccess];
        @weakify(self)
        SCFetchExpressInfoAPI *infoApi = [[SCFetchExpressInfoAPI alloc] init];
        infoApi.expCode = code;
        [infoApi startWithCompletionWithSuccess:^(id responseDataDict) {
            @strongify(self)
            NSArray *expList = (NSArray *)responseDataDict;
            if (expList && (expList.count > 0)) {
                NSMutableArray *result = [SCExpress mj_objectArrayWithKeyValuesArray:expList];
                if ([result count] == 1) {
                    [SVProgressHUD dismiss];
                    SCExpress *express = (SCExpress *)[result objectAtIndex:0];
                    NSLog(@"-----代收者 = %@------",express.accepter);
                    [self dispatchExpress:express isAccepted:express.accepted];
                } else if ([result count] > 1) {
                    [SVProgressHUD dismiss];
                    NSLog(@"------有很多个------");
                    [self jumpToMultiExpressVC:result];
                }
            } else {
                [SVProgressHUD showErrorWithStatus:@"快递信息不存在" duration:1.0 dismiss:^{
                    [self.session startRunning];
                }];
            }
        } failure:^(NSError *error) {
            [SCAlertHelper handleError:error];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.session startRunning];
            });
        }];
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }
}

// 根据快递状态跳转到不同的快递页
- (void)dispatchExpress:(SCExpress *)express isAccepted:(BOOL)accepted {
    if (express.accepted) {
        SCExpAcceptViewController *acceptedVC = [[SCExpAcceptViewController alloc] initWithNibName:[SCExpAcceptViewController sc_className] bundle:nil];
        acceptedVC.express = express;
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self.navigationController pushViewController:acceptedVC animated:YES];
        });
    } else {
        SCExpUnAcceptViewController *unAcceptedVC = [[SCExpUnAcceptViewController alloc] initWithNibName:[SCExpUnAcceptViewController sc_className] bundle:nil];
        unAcceptedVC.express = express;
        unAcceptedVC.throughScan = YES;
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self.navigationController pushViewController:unAcceptedVC animated:YES];
        });
    }
}

// 访客通行二维码处理
- (void)dispatchPassportScanResult:(NSString *)code {
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeVisitorQuery]) {
        // 埋点 二维码扫描-成功扫描访客二维码 add by jqb 2018/8/4
        [SCTrackManager trackEvent:kStatusEventQRCodeScanVisitorSuccess];
        // 在此进行校验请求 如果是是车访出场  需要跳转到访客详情
        SCVisitorPasscodeVerifyAPI *passcodeVerifyAPI = [[SCVisitorPasscodeVerifyAPI alloc] init];
        [SVProgressHUD showWithStatus:@"正在验证..."];
        passcodeVerifyAPI.passCode = code;
        @weakify(self)
        [passcodeVerifyAPI startWithCompletionWithSuccess:^(id responseDataDict) {
            @strongify(self)
            [SVProgressHUD dismiss];
            SCVisitorPassCodeModel *passInfoModel = [SCVisitorPassCodeModel mj_objectWithKeyValues:responseDataDict];
            [self dealWithPasscodeVerifyResult:passInfoModel];
        } failure:^(NSError *error) {
            @strongify(self)
            [SCAlertHelper handleError:error];
            [self.session startRunning];
        }];
        
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }
}

////  访客通行证校验的处理结果
- (void)dealWithPasscodeVerifyResult:(SCVisitorPassCodeModel *)model  {
    
    if (!model) {
        [self.session startRunning];
        return;
    }
    
    /// 如果是是车访出场，且有账单  需要跳转到访客详情
    if (model.passStatusType == SCVisitorPassStatusCarLeave && model.isHaveOrder) {
        SCVisitorDetailController *controller = [[SCVisitorDetailController alloc] initWithNibName:[SCVisitorDetailController sc_className] bundle:nil];
        controller.visitorId = ISNULL(model.visitor.visitorId);
        [self.navigationController pushViewController:controller animated:YES];
        
    } else {
        /// 其他依旧跳转到通行证扫描结果页面
        SCPassResultViewController *resultVC = [[SCPassResultViewController alloc] initWithNibName:[SCPassResultViewController sc_className] bundle:nil];
        resultVC.passInfoModel = model;
        SCBaseNavigationController *nav = [[SCBaseNavigationController alloc] initWithRootViewController:resultVC];
        [self presentViewController:nav animated:YES completion:^{}];
    }
}

// 活动签到二维码处理
- (void)dispatchActivitySignInScanResult:(NSString *)code {
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeActivitySign]) {
        // 埋点 二维码扫描-成功扫描活动签到二维码 add by jqb 2018/8/4
        [SCTrackManager trackEvent:kStatusEventQRCodeScanAcitivitySignSuccess];
        SCActivityDetailController *signInVC = [[SCActivityDetailController alloc] initWithNibName:[SCActivityDetailController sc_className] bundle:nil];
        signInVC.signCode = code;
        signInVC.entryWay = SCActivityDetailEnterWaySignIn;
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self.navigationController pushViewController:signInVC animated:YES];
        });
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }
}

// 物品寄存二维码处理
- (void)dispatchDepositScanResult:(NSString *)code {
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeDeposit]) {
        // 埋点 二维码扫描-成功扫描寄存取件码 add by jqb 2018/8/4
        [SCTrackManager trackEvent:kStatusEventQRCodeScanDepositSuccess];
        SCDepositDetailController *depositVC = [[SCDepositDetailController alloc] initWithNibName:NSStringFromClass([SCDepositDetailController class]) bundle:nil];
        depositVC.depositNo = code;
        [self.navigationController pushViewController:depositVC animated:YES];
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }
}

// 设备二维码处理(需判断去设施还是巡检,维保)
- (void)dispatchDeviceScanResult:(NSString *)code {
    @weakify(self)
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *deviceAccountAction = [UIAlertAction actionWithTitle:@"去设备" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self)
        if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeDeviceAccount]) {
            // 埋点 二维码扫描-成功扫描设备码 add by jqb 2018/8/4
            [SCTrackManager trackEvent:kStatusEventQRCodeScanDeviceSuccess];
            [self.scanHelper deviceAccountQrcodeScanResult:code controller:self failureBlock:^(NSError *error) {
                [SCAlertHelper handleError:error duration:1.0 dismiss:^{
                    [self.session startRunning];
                }];
            }];
        } else {
            [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
                @strongify(self)
                [self.session startRunning];
            }];
        }
    }];
    UIAlertAction *devicePatrolAction = [UIAlertAction actionWithTitle:@"去巡检" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self)
        if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeDevicePatrol]) {
            // 埋点 二维码扫描-成功扫描巡检码 add by jqb 2018/8/4
            [SCTrackManager trackEvent:kStatusEventQRCodeScanPatrolSuccess];
            [self.scanHelper devicePatrolQrcodeScanResult:code controller:self failureBlock:^(NSError *error) {
                [SCAlertHelper handleError:error duration:1.0 dismiss:^{
                    [self.session startRunning];
                }];
            }];
        } else {
            [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
                @strongify(self)
                [self.session startRunning];
            }];
        }
    }];
    UIAlertAction *deviceMaintAction = [UIAlertAction actionWithTitle:@"去维保" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self)
        if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeDeviceMaint]) {
            [self.scanHelper deviceMaintQrcodeScanResult:code controller:self failureBlock:^(NSError *error) {
                [SCAlertHelper handleError:error duration:1.0 dismiss:^{
                    [self.session startRunning];
                }];
            }];
        } else {
            [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
                @strongify(self)
                [self.session startRunning];
            }];
        }
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self.session startRunning];
    }];
    [alertVC addAction:deviceAccountAction];
    [alertVC addAction:devicePatrolAction];
    [alertVC addAction:deviceMaintAction];
    [alertVC addAction:cancelAction];
    [self presentViewController:alertVC animated:YES completion:nil];
}

/// 巡查二维码处理
- (void)dispatchPatorlManagerScanResult:(NSString *)code {
    @weakify(self)
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodePatrolManager] ) {
        // 埋点 二维码扫描-成功扫描巡查码 add by jqb 2018/8/4
        [SCTrackManager trackEvent:kStatusEventQRCodeScanInspectionSuccess];
        [self.scanHelper patrolManagerQrcodeScanResult:code controller:self failureBlock:^(NSError *error) {
            @strongify(self)
            [SCAlertHelper handleError:error duration:1.0 dismiss:^{
                [self.session startRunning];
            }];
        }];
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            @strongify(self)
            [self.session startRunning];
        }];
    }
}

/// 抄表二维码处理方式
- (void)dispatchPanelMeterScanResult:(NSString *)code {
    @weakify(self)
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodePanelMeter]) {
        // 埋点 二维码扫描-成功扫描抄表码 add by jqb 2018/8/4
        [SCTrackManager trackEvent:kStatusEventQRCodeScanMeterReadingSuccess];
        [self.scanHelper panelMeterQrcodeScanResult:code controller:self failureBlock:^(NSError *error) {
            @strongify(self)
            [SCAlertHelper handleError:error duration:1.0 dismiss:^{
                [self.session startRunning];
            }];
        }];
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            @strongify(self)
            [self.session startRunning];
        }];
    }
    
}

// 共享停车二维码处理
- (void)dispatchCarSharedScanResult:(NSString *)code {
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeCarParkManager]) {
        // 埋点 二维码扫描    成功扫描共享停车码 add by jqb 2018/8/4
        [SCTrackManager trackEvent:kStatusEventQRCodeScanSharedParkingSuccess];
        SCCarParkDetailViewController *detailsVC = [[SCCarParkDetailViewController alloc] initWithNibName:[SCCarParkDetailViewController sc_className] bundle:nil];
        detailsVC.qRcode = code;
        [self.navigationController pushViewController:detailsVC animated:YES];
    } else {
        @weakify(self)
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            @strongify(self)
            [self.session startRunning];
        }];
    }
}

// 多个快递的处理
- (void)jumpToMultiExpressVC:(NSMutableArray *)expresses {
    SCExpMultiSignViewController *signVC = [[SCExpMultiSignViewController alloc] initWithNibName:[SCExpMultiSignViewController sc_className] bundle:nil];
    signVC.expresses = expresses;
    signVC.throughScan = YES;
    [self.navigationController pushViewController:signVC animated:YES];
}

// 扫条形码的处理
- (void)jumpToManualCodeVC:(NSString *)expNum {
    SCManualBarCodeViewController *barVC = [[SCManualBarCodeViewController alloc] initWithNibName:[SCManualBarCodeViewController sc_className] bundle:nil];
    barVC.expNum = expNum;
    barVC.fromScan = YES;
    [self.navigationController pushViewController:barVC animated:YES];
}

/// 处理物品出门
- (void)dispatchGoodsAccessScanResult:(NSString *)code {
    
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeGoodsAccess]) {
        SCGoodsAccessDetailAPI *detailAPI = [[SCGoodsAccessDetailAPI alloc] init];
        detailAPI.qrCode = code;
        [SVProgressHUD show];
        @weakify(self);
        [detailAPI startWithCompletionWithSuccess:^(id responseDataDict) {
            @strongify(self);
            [SVProgressHUD dismiss];
            SCGoodsAccessDetailModel *model = [SCGoodsAccessDetailModel mj_objectWithKeyValues:responseDataDict];
            if (model) {
                SCGoodsAccessAddController *vc = [[SCGoodsAccessAddController alloc] initWithNibName:NSStringFromClass([SCGoodsAccessAddController class]) bundle:nil];
                vc.goodsAccessModel = model;
                [self.navigationController pushViewController:vc animated:YES];
            } else {
                [SVProgressHUD showErrorWithStatus:@"暂未获取到物品出门信息" duration:1.0 dismiss:^{
                    [self.session startRunning];
                }];
            }
            
        } failure:^(NSError *error) {
            @strongify(self);
            [self.session startRunning];
            [SCAlertHelper handleError:error];
        }];
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }
}

/// 处理物品借出
- (void)dispatchGoodsBorrowScanResult:(NSString *)code {
    if ([SCGlobalDataManager menuItemViewAuthWithCode:SCMenuItemCodeGoodsBorrow]) {

        @weakify(self);
        SCGoodsBorrowLendQRCodeAPI *api = [[SCGoodsBorrowLendQRCodeAPI alloc] init];
        api.qrcode = code;
        [SVProgressHUD show];
        [api startWithCompletionWithSuccess:^(id responseDataDict) {
            [SVProgressHUD dismiss];
            @strongify(self);
            SCGoodsBorrowListModel *model = [SCGoodsBorrowListModel mj_objectWithKeyValues:responseDataDict];
            if (model) {
                [self dealWithModel:model];
            
            } else {
                [SVProgressHUD showErrorWithStatus:@"暂未获取到物品借用信息" duration:1.0 dismiss:^{
                    [self.session startRunning];
                }];
            }
        } failure:^(NSError *error) {
            @strongify(self);
            [self.session startRunning];
            [SCAlertHelper handleError:error];
        }];
        
    } else {
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            [self.session startRunning];
        }];
    }
}

/// 订单核销页面
- (void)dispatchWriteOffOrderScanResult:(NSString *)code {
    
    if ([SCGlobalDataManager sharedInstance].canWriteOffOrder) {
        if (self.needBack) {
            /// 代表是从详情进来的
            !self.scanQRCodeBlock ? : self.scanQRCodeBlock(code);
            [self dismissViewControllerAnimated:YES completion:^{ }];
        } else {
            /// 代表是从扫一扫进来的
            SCWriteOffOrderDetailController *controller = [[SCWriteOffOrderDetailController alloc] initWithNibName:[SCWriteOffOrderDetailController sc_className] bundle:nil];
            controller.qrCode = code;
            controller.enterWay = SCWriteOffDetailEnterWayScan;
            [self.navigationController pushViewController:controller animated:YES];
        }
    } else {
        @weakify(self)
        [SVProgressHUD showErrorWithStatus:@"暂无相关权限" duration:1.0 dismiss:^{
            @strongify(self)
            [self.session startRunning];
        }];
    }
}

- (void)dealWithModel:(SCGoodsBorrowListModel *)model
{
    switch (model.lendStatus) {
        case SCGoodsBorrowStatusLendWaiting: {
            SCOwnerBorrowViewController *owner = [[SCOwnerBorrowViewController alloc] initWithNibName:[SCOwnerBorrowViewController sc_className] bundle:nil];
            owner.isFromScanOwnerCode = YES;
            owner.qrcodeDetail = model;
            [self.navigationController pushViewController:owner animated:YES];
        }
            break;
        case SCGoodsBorrowStatusGiveBackWaiting:
        {
            SCGoodsBorrowGiveBackController *giveBack = [[SCGoodsBorrowGiveBackController alloc] initWithNibName:[SCGoodsBorrowGiveBackController sc_className] bundle:nil];
            giveBack.orderId = model.orderId;
            [self.navigationController pushViewController:giveBack animated:YES];
        }
            break;
        case SCGoodsBorrowStatusGiveBackDone:
        {
            SCGoodsBorrowGiveBackDoneController *giveBackDone = [[SCGoodsBorrowGiveBackDoneController alloc] initWithNibName:[SCGoodsBorrowGiveBackDoneController sc_className] bundle:nil];
            giveBackDone.orderId = model.orderId;
            [self.navigationController pushViewController:giveBackDone animated:YES];
        }
            break;
        case SCGoodsBorrowStatusInvaild:
            [SVProgressHUD showErrorWithStatus:@"二维码已失效" duration:1.5 dismiss:nil];
            break;
        default:
            [SVProgressHUD showErrorWithStatus:@"二维码已失效" duration:1.5 dismiss:nil];
            break;
    }
}

@end
