//
//  SCSearchView.m
//  Butler
//
//  Created by 小广 on 2017/3/28.
//  Copyright © 2017年 UAMA Inc. All rights reserved.
//  车访登记的搜索Bar的view

#import "SCSearchView.h"

CGFloat SCSearchBarHeight(void) {
    return 44.0 + SCStatusBarHeight;
};

@interface SCSearchView () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancelButtonWidthConstraint;

@end

@implementation SCSearchView

+ (id)loadNibView {
    return [[[NSBundle mainBundle] loadNibNamed:[SCSearchView sc_className] owner:self options:nil] objectAtIndex:0];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.clipsToBounds = YES;
    
    [self.searchBar.layer setMasksToBounds:YES];
    self.searchBar.layer.cornerRadius = 5.0;
    self.showCancelButton = YES;
    self.searchTextField.delegate = self;
    self.searchTextField.borderStyle = UITextBorderStyleNone;
    self.searchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
}

- (void)setIsShowNav:(BOOL)isShowNav {
    _isShowNav = isShowNav;
    
    if (_isShowNav) {
        self.topConstraint.constant = 8 + SCStatusBarHeight;
        
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCSearchBarHeight());
        gradient.colors = @[(__bridge id)[SC_NAVBAR_BEGIN_COLOR CGColor], (__bridge id)[SC_NAVBAR_END_COLOR CGColor]];
        gradient.startPoint = CGPointMake(0, 0);
        gradient.endPoint = CGPointMake(0, 1);
        [self.layer addSublayer:gradient];
        
        [self bringSubviewToFront:self.searchBar];
        [self bringSubviewToFront:self.cancelButton];
    }
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = placeholder;
    
    self.searchTextField.placeholder = _placeholder;
}

- (void)setKeyboardType:(UIKeyboardType)keyboardType {
    self.searchTextField.keyboardType = keyboardType;
}

- (void)setText:(NSString *)text {
    _text = text;
    self.searchTextField.text = ISNULL(text);
}

- (void)setBackColor:(UIColor *)backColor {
    _backColor = backColor;
    
    self.backgroundColor = _backColor;
}

- (void)setShowCancelButton:(BOOL)showCancelButton {
    _showCancelButton = showCancelButton;
    
    if (_showCancelButton) {
        self.cancelButtonWidthConstraint.constant = 50.0f;
        self.cancelButton.hidden = NO;
    } else {
        self.cancelButtonWidthConstraint.constant = 8.0f;
        self.cancelButton.hidden = YES;
    }
}

- (void)setCancelButtonTitle:(NSString *)cancelButtonTitle {
    [self.cancelButton setTitle:cancelButtonTitle forState:UIControlStateNormal];
}


- (IBAction)cancelButtonAction:(UIButton *)sender {
    if (self.cancelAction) {
        self.cancelAction();
    }
}

#pragma mark - FirstResponder
- (BOOL)canBecomeFirstResponder{
    return YES;
}

- (BOOL)becomeFirstResponder{
    return  [self.searchTextField becomeFirstResponder];
}

- (BOOL)resignFirstResponder{
    [super resignFirstResponder];
    return [self.searchTextField resignFirstResponder];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (self.searchAction) {
        self.searchAction(textField.text);
    }
    return YES;
}


@end
