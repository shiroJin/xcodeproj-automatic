//
//  SCGoodsBorrowScanInputViewController.m
//  Butler
//
//  Created by Linkou Bian on 8/25/14.
//  Copyright (c) 2014 UAMA Inc. All rights reserved.
//

#import "SCGoodsBorrowScanInputViewController.h"

#import "SCBaseNavigationController.h"
#import "SCPassResultViewController.h"
#import "SCExpUnAcceptViewController.h"
#import "SCExpAcceptViewController.h"
#import "SCExpMultiSignViewController.h"
#import "SCManualBarCodeViewController.h"
#import "SCActivityDetailController.h"
#import "SCDepositDetailViewController.h"
#import "SCDeviceAccountItemViewController.h"
#import "SCCarParkDetailViewController.h"
#import "SCUniversalCodeResultController.h"
#import "SCOfflineActivitySignInController.h"
#import "SCWebViewController.h"
#import "SCCodeInputViewController.h"
#import "SCOwnerBorrowViewController.h"

#import "SCExpress.h"
#import "SCUniversalCodeResult.h"
#import "SCofflineActivitySignUpDetail.h"
#import "SCScanBottomView.h"

#import "SCScanner.h"
#import "WESoundHelper.h"
#import "SCHomeScanQrcodeHelper.h"
#import "SCDeviceAuthManager.h"
#import "SCOfflineActivityMananger.h"
#import "SCQrCodeDecryptHelper.h"
#import "SCDeviceAccountManager.h"
#import "SCFetchExpressInfoAPI.h"
#import "SCUniversalCodeResultAPI.h"

#import "SCVisitorDetailController.h"
#import "SCVisitorPasscodeVerifyAPI.h"

#import "SCGoodsAccessAddController.h"
#import "SCGoodsAccessDetailAPI.h"

@interface SCGoodsBorrowScanInputViewController ()<AVCaptureMetadataOutputObjectsDelegate>

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
/// 闪光灯是否打开
@property (nonatomic, assign) BOOL torchFlashed;
/// 手电按钮设置为全局变量，主要是弹出alert/跳转到下一页的时候，会自动关掉；然后就无法再次打开，所以全局记录一下
@property (nonatomic, strong) UIButton  *flashBtn;

@property (nonatomic, strong) SCHomeScanQrcodeHelper *scanHelper;

@end

@implementation SCGoodsBorrowScanInputViewController

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
    
    [self fetchAuthorizationOfCamera];
    [self setUpUIWithTransparentSize:self.transparentSize];
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
    /// 重置闪光灯按钮
    self.torchFlashed = NO;
    self.flashBtn.enabled = YES;
    [self.flashBtn setImage:[UIImage imageNamed:@"lamp_off"] forState:UIControlStateNormal];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    /// 重置提示语句
    [self resetMessage];
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
    self.scanView.scanType = SCSanSourceTypeQR;
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
    
    // 设置底部按钮
    [self layoutBottomView];
    
    if (self.scanFrameView == nil) {
        self.scanFrameView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"code_scannner"]];
    }
    
    [self.scanFrameView setFrame:CGRectMake(self.view.center.x - 120, self.view.center.y - 120, 240, 240)];
    
    [self.maskView addSubview:self.scanFrameView];
    [self.view addSubview:self.maskView];
}


#pragma mark - 物品借用新增
/// 手动输入按钮的布局
- (void)layoutBottomView {
    /// 模块的code(物品借出,物品出门,需要有手动输入按钮，需要传itemCode)（+号按钮的也算上）
    if (!_bottomView) {
        _bottomView = [SCScanBottomView loadScanBottomView];
    }
    _bottomView.menuItemCode = self.itemCode;
    [self.maskView addSubview:self.bottomView];
    [self.bottomView setFrame:CGRectMake(0.f, SCREEN_HEIGHT- 20.f - SCHomeIndicatorHeight - 60.f, SCREEN_WIDTH, 60.f)];
    @weakify(self)
    self.bottomView.itemSeletced = ^(NSInteger index, NSString *itemTitle) {
        /// 统计
        [SCTrackManager trackEvent:kScanTabClick attributes:@{@"tabName":itemTitle}];
        @strongify(self)
        [self actionForManualInput];
    };
    
}

/// 二维码扫描框下面的提示语句
- (void)resetMessage {
    
    NSString *message = @"";
    switch (self.itemCode) {
        case SCMenuItemLocalCodeGoodsBorrow:
        case SCMenuItemCodeGoodsBorrow:
            /// 物品出门登记
            message = @"请扫描业主万能二维码";
            break;
            
        default:
            break;
    }
    
    self.scanView.message = message;
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


//手动输入跳转，目前只支持物品借用
- (void)actionForManualInput
{
    if (self.itemCode == SCMenuItemCodeGoodsBorrow || self.itemCode == SCMenuItemLocalCodeGoodsBorrow) {
        SCOwnerBorrowViewController *owner = [[SCOwnerBorrowViewController alloc] initWithNibName:[SCOwnerBorrowViewController sc_className] bundle:nil];
        [self.navigationController pushViewController:owner animated:YES];
    }
}


#pragma mark AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSString *stringValue;
    
    if ([metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        stringValue = metadataObject.stringValue;
        NSString *typeStr = metadataObject.type;
        if ([typeStr isEqualToString:AVMetadataObjectTypeQRCode]) {
            [self.session stopRunning];
            NSLog(@"stringValue =  %@",stringValue);
            [self onScanned:stringValue];
            
        } else {
            [self.session stopRunning];
            [self showError];
        }
    }
}

#pragma mark - Private
// 扫描结束后处理
- (void)onScanned:(NSString *)result {
    [WESoundHelper playSoundFromFile:@"beep.wav" fromBundle:[NSBundle mainBundle] asAlert:YES];
    [self dispatchQRCode:result];
}


// 根据二维码类型进行不同处理
- (void)dispatchQRCode:(NSString *)code {
    [MobClick event:@"Home_Scan_QRCode"];
    if ([SCQrCodeDecryptHelper judgeWithqrCode:code]) {
        // 如果是以uama_开头，则说明是内部新规则的二维码
        [self hasPrefixUamaQrCodeHandel:code];
    }
    else if ([code hasPrefix:kUniversalQrCodePrefix]) {
        // 如果是以UM_开头，则说明是新万能二维码
        [self dispatchUniversalCodeResult:code];
    }
    else {
        [self showError];
    }
}


// 新规则的二维码处理
- (void)hasPrefixUamaQrCodeHandel:(NSString *)code {
    @weakify(self)
    [SCQrCodeDecryptHelper decryptWithQrCode:code success:^(SCQRCodeType type, NSString *acode) {
        @strongify(self)
        if (type == SCQRCodeTypeUniversal) {
            // 万能二维码
            [self dispatchUniversalCodeResult:code];
        } else {
            
            [self showError];
        }
        
    } failure:^(NSError *error) {
        [self showError];
    }];
}

- (void)showError
{
    [SVProgressHUD showErrorWithStatus:@"请扫描业主万能二维码" duration:1.0 dismiss:^{
        [self.session startRunning];
    }];
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
        SCOwnerBorrowViewController *ownerVc = [[SCOwnerBorrowViewController alloc] initWithNibName:[SCOwnerBorrowViewController sc_className] bundle:nil];
        ownerVc.result = result;
        [self.navigationController pushViewController:ownerVc animated:YES];
    
    } failure:^(NSError *error) {
        @strongify(self)
        [SCAlertHelper handleError:error];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.session startRunning];
        });
    }];
}


@end
