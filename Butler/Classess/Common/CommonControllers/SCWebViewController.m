//
//  SCWebViewController.m
//  Butler
//
//  Created by zhanglijiong on 2017/8/5.
//  Copyright © 2017年 UAMA Inc. All rights reserved.
//

#import "SCWebViewController.h"

@interface SCWebViewController ()

@property (nonatomic, strong) UIButton *closeButton;

@end

@implementation SCWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //[self.navigationController setNavigationBarHidden:NO animated:NO];
    self.toolbarHidden = YES;
    
    //self.webView.scrollView.bounces = NO;
    
    [self setNavigationButton];
    
    // Do any additional setup after loading the view.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)webViewDidFinishLoad:(UIWebView*)webView {
    [super webViewDidFinishLoad:webView];
    
    if (self.scTitle) {
        self.title = self.scTitle;
    }else{
        //若没有标题传入，则直接从web页面读取
        NSString *theTitle=[webView stringByEvaluatingJavaScriptFromString:@"document.title"];
        if (theTitle.length > 10) {
            theTitle = [[theTitle substringToIndex:9] stringByAppendingString:@"…"];
        }
        self.title = theTitle;
    }
    
    
    if ([self.webView canGoBack])
    {
        self.closeButton.hidden = NO;
    }else
        self.closeButton.hidden = YES;
}

- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
    [super webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    
    if ([self.webView canGoBack])
    {
        self.closeButton.hidden = NO;
    }else
        self.closeButton.hidden = YES;
    return YES;
}


#pragma mark - Privite Method

- (void)setNavigationButton {
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 88, 44)];
    
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:[UIImage imageNamed:@"navbar_back"] forState:UIControlStateNormal];
    [backButton sizeToFit];
    [backButton setTitle:@"返回" forState:UIControlStateNormal];
    [backButton.titleLabel setFont:[UIFont systemFontOfSize:16]];
    backButton.contentEdgeInsets = UIEdgeInsetsMake(0, -10, 0, 0);
    backButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
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

- (void)getBackAction {
    if ([self.webView canGoBack]) {
        
        [self.webView goBack];
    }else
        [self.navigationController popViewControllerAnimated:YES];
}

- (void)closeCurrentViewAction {
    [self.navigationController popViewControllerAnimated:YES];
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
