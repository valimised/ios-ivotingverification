//
//  UICustomAlertView.m
//  v 1.0
//
//  Created by Sander Hunt on 9/5/13.
//  Copyright (c) 2013 Applaud. All rights reserved.
//

#import "ALCustomAlertView.h"
#import <QuartzCore/QuartzCore.h>

#define IS_IPAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@implementation ALCustomAlertView

static const float kCustomAlertViewMinWidth = 160.0f;
static bool isKeyboardVisible = false;

@synthesize mTitle;
@synthesize mCancelButton;
@synthesize mConfirmButton;
@synthesize mDelegate;
@synthesize mKeyboardAdjustType;
@synthesize mAlertView;

CAViewPaddingInfo CAViewPaddingInfoCreate(float _left, float _right, float _top, float _bottom) {
    CAViewPaddingInfo result;
    result.top      = _top;
    result.bottom   = _bottom;
    result.left     = _left;
    result.right    = _right;
    return result;
}

#pragma mark - Internal methods

- (void)_internalCancelCallback
{
    if (mDelegate && [mDelegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
        [mDelegate alertView:self clickedButtonAtIndex:0];
    }
    
    if(mDelegate!=nil && [mDelegate respondsToSelector:@selector(cancelButtonPressed:)]) [mDelegate cancelButtonPressed:self];
    
    if(mCancelCallbackTarget != nil && mCancelCallback!=nil && [mCancelCallbackTarget respondsToSelector:mCancelCallback]) {
        [mCancelCallbackTarget performSelector:mCancelCallback];
    }
    
    [self hide];
}

- (void)_internalConfirmCallback
{
    if (mDelegate && [mDelegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
        [mDelegate alertView:self clickedButtonAtIndex:1];
    }
    
    if(mDelegate!=nil && [mDelegate respondsToSelector:@selector(confirmButtonPressed:)]) [mDelegate confirmButtonPressed:self];
    [self hide];
}

#pragma mark - Init methods

- (id)initWithFrame:(CGRect)frame
{
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
    }
    return self;
}

- (id)initWithTitleText:(NSString *)_titleText withCancelButtonText:(NSString *)_cancelButtonText withCustomView:(UIView *)_customView withPaddingInfo:(CAViewPaddingInfo)_paddingInfo withConfirmButtonText:(NSString *)_confirmButtonText withMakeSquare:(BOOL)makeSquare
{
    self = [self initWithFrame:[[UIScreen mainScreen] bounds]];
 
    UIColor *bgColor                = [UIColor colorWithWhite:0.0f alpha:0.2f];
    
    UIColor *alertViewBgColor = nil;
    UIColor *titleColor = nil;
    
    alertViewBgColor = [UIColor colorWithWhite:0.0f alpha:0.9f];
    titleColor = [UIColor whiteColor];
    
    UIColor *titleBgColor           = [UIColor colorWithWhite:0.0f alpha:0.0f];
    
    UIColor *cancelButtonBgColor    = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.1f];
    UIColor *confirmButtonBgColor   = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.1f];
    
    UIColor *cancelButtonTitleColor = [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1.0f];
    UIColor *confirmButtonTitleColor= [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1.0f];
    
    UIColor *separatorViewColor     = [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:0.3f];

    
    UIFont *titleFont               = [UIFont boldSystemFontOfSize:17.0f];
    UIFont *buttonFont              = [UIFont boldSystemFontOfSize:15.0f];
    
    UIActivityIndicatorViewStyle spinnerStyle = UIActivityIndicatorViewStyleWhiteLarge;
    
    mCustomView = _customView;
 
    mKeyboardAdjustType = VisibleCustomView;
    
    bool createCancelButton = !(_cancelButtonText==nil || _cancelButtonText.length < 1);
    bool createConfirmButton = !(_confirmButtonText==nil || _confirmButtonText.length < 1);
    bool createBothButtons = (createCancelButton && createConfirmButton);
    
    self.backgroundColor = bgColor;
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    float alertViewHeight = 0.0f;
    float alertViewWidth = 0.0f;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    CGSize titleTextSize = [_titleText sizeWithFont:titleFont];
    CGSize cancelButtonTextSize = [_cancelButtonText sizeWithFont:buttonFont];
    CGSize confirmButtonTextSize = [_confirmButtonText sizeWithFont:buttonFont];
#pragma clang diagnostic pop
    
    float titleHeight = titleTextSize.height * 2.3f;
    float buttonsHeight = 0.0f;
    
    {
        float cancelButtonHeight = (createCancelButton) ? (cancelButtonTextSize.height * 2.4f) : 0.0f;
        float confirmButtonHeight = (createConfirmButton) ? (confirmButtonTextSize.height * 2.4f) : 0.0f;
        buttonsHeight = MAX(cancelButtonHeight, confirmButtonHeight);
    }
    
    mButtonsHeight = buttonsHeight;
    
    float middleViewHeight = 0.0f;
    
    float titleWidth = ( titleTextSize.width + 30.0f );
    float cancelButtonWidth = (createCancelButton) ? ( MAX(cancelButtonTextSize.width + 30.0f, confirmButtonTextSize.width + 30.0f ) ) : 0.0f;
    float confirmButtonWidth = (createConfirmButton) ? ( MAX(confirmButtonTextSize.width + 30.0f, cancelButtonTextSize.width + 30.0f ) ) : 0.0f;
    float buttonsWidth = cancelButtonWidth + confirmButtonWidth;
    if(createBothButtons) {
        buttonsWidth += 1; // additional 1 point for the separator
    }
    float middleViewWidth = 0.0f;
    
    if(mCustomView == nil) {
        mSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:spinnerStyle];
        _paddingInfo.top = mSpinner.frame.size.height / 2.0f;
        _paddingInfo.bottom = _paddingInfo.top;
        _paddingInfo.left = 0.0f;
        _paddingInfo.right = 0.0f;
        middleViewHeight = mSpinner.frame.size.height;
        middleViewWidth = mSpinner.frame.size.width;
    } else {
        middleViewHeight = mCustomView.frame.size.height;
        middleViewWidth = mCustomView.frame.size.width;
    }
    
    middleViewHeight += _paddingInfo.bottom + _paddingInfo.top;
    
    alertViewHeight = ( titleHeight + middleViewHeight + buttonsHeight );
    alertViewWidth = MAX(MAX(titleWidth, (middleViewWidth+_paddingInfo.left+_paddingInfo.right)), buttonsWidth );
    
    if(makeSquare && alertViewWidth < alertViewHeight) {
        alertViewWidth = alertViewHeight;
    }
    
    if(buttonsWidth < alertViewWidth) {
        float widthLeftover = (alertViewWidth - buttonsWidth);
        if(createCancelButton) {
            cancelButtonWidth += ( createConfirmButton ) ? ( widthLeftover / 2.0f ) : widthLeftover;
        }
        if(createConfirmButton) {
            confirmButtonWidth += ( createCancelButton ) ? ( widthLeftover / 2.0f ) : widthLeftover;
        }
    }
    
    mAlertView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, alertViewWidth, alertViewHeight)];
    CGRect frame = mAlertView.frame;
    frame.origin.x = [self center].x - alertViewWidth / 2.0f;
    frame.origin.y = [self center].y - alertViewHeight / 2.0f;
    mAlertView.frame = frame;
    mAlertView.layer.cornerRadius = 10.0f;
    mAlertView.clipsToBounds = YES;
    mAlertView.backgroundColor = alertViewBgColor;
    
    if(createCancelButton){
        mCancelButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, titleHeight + middleViewHeight, cancelButtonWidth, buttonsHeight)];
        [mCancelButton setTitle:_cancelButtonText forState:UIControlStateNormal];
        [mCancelButton setTitleColor:cancelButtonTitleColor forState:UIControlStateNormal];
        [mCancelButton setBackgroundColor:cancelButtonBgColor];
        [mCancelButton.titleLabel setFont:buttonFont];
        [mCancelButton addTarget:self action:@selector(_internalCancelCallback) forControlEvents:UIControlEventTouchUpInside];
    }
    
    if(createConfirmButton){
        float x = ( createCancelButton ) ? ( cancelButtonWidth + 1.0f ) : 0.0f;
        mConfirmButton = [[UIButton alloc] initWithFrame:CGRectMake(x, titleHeight + middleViewHeight, confirmButtonWidth, buttonsHeight)];
        [mConfirmButton setTitle:_confirmButtonText forState:UIControlStateNormal];
        [mConfirmButton setTitleColor:confirmButtonTitleColor forState:UIControlStateNormal];
        [mConfirmButton setBackgroundColor:confirmButtonBgColor];
        [mConfirmButton.titleLabel setFont:buttonFont];
        [mConfirmButton addTarget:self action:@selector(_internalConfirmCallback) forControlEvents:UIControlEventTouchUpInside];
    }
    
    if(createBothButtons) {
        mButtonSeparatorView = [[UIView alloc] initWithFrame:CGRectMake(cancelButtonWidth, titleHeight + middleViewHeight, 1.0f, buttonsHeight)];
        [mButtonSeparatorView setBackgroundColor:separatorViewColor];
    }
    
    if(_customView == nil) {
        CGRect spinnerFrame = mSpinner.frame;
        spinnerFrame.origin.x = mAlertView.frame.size.width / 2.0f - spinnerFrame.size.width / 2.0f;
        spinnerFrame.origin.y = titleHeight + _paddingInfo.top;
        [mSpinner setFrame:spinnerFrame];
        [mSpinner startAnimating];
    } else {
        mCustomView = _customView;
        CGRect customViewFrame = mCustomView.frame;
        customViewFrame.origin.y = titleHeight + _paddingInfo.top;
        customViewFrame.origin.x = (alertViewWidth / 2.0f) - (customViewFrame.size.width/2.0f);
        mCustomView.frame = customViewFrame;
    }
    
    mTitle = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, alertViewWidth, titleHeight)];
    [mTitle setLineBreakMode:NSLineBreakByWordWrapping];
    [mTitle setNumberOfLines:2];
    [mTitle setFont:titleFont];
    [mTitle setText:_titleText];
    [mTitle setTextColor:titleColor];
    [mTitle setBackgroundColor:titleBgColor];
    [mTitle setTextAlignment:NSTextAlignmentCenter];
    
    if(createCancelButton)[mAlertView addSubview:mCancelButton];
    if(createConfirmButton)[mAlertView addSubview:mConfirmButton];
    if(createBothButtons)[mAlertView addSubview:mButtonSeparatorView];
    if(mCustomView==nil) [mAlertView addSubview:mSpinner];
    else [mAlertView addSubview:mCustomView];
    [mAlertView addSubview:mTitle];
    
    [self addSubview:mAlertView];
    
    self.hidden = YES;
    
    return self;
}

- (id)initWithOptions:(NSDictionary *)options
{
    NSString * message = options[kAlertViewMessage];
    NSString * title = options[kAlertViewTitle];
    NSString * cancelButtonText = options[kAlertViewCancelButtonTitle];
    NSString * confirmButtonText = options[kAlertViewConfrimButtonTitle];
    UIColor * foregroundColor = options[kAlertViewForegroundColor];
    UIColor * backgroundColor = options[kAlertViewBackgroundColor];
    
    UILabel * contentLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 260, 0)];
    
    // Suggested boundingRectWithSize:options:attributes:context: is only available in iOS7
    // but we're supporting older verisions of the OS.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    CGSize textSize = [message sizeWithFont:contentLabel.font constrainedToSize:CGSizeMake(contentLabel.bounds.size.width, MAXFLOAT)];
#pragma clang diagnostic pop
    
    CGRect labelFrame = CGRectMake(0, 0, contentLabel.bounds.size.width, textSize.height);
    
    if (foregroundColor)    contentLabel.textColor = foregroundColor;
    else                    contentLabel.textColor = [UIColor whiteColor];
    
    contentLabel.text = message;
    contentLabel.frame = labelFrame;
    contentLabel.numberOfLines = 0;
    contentLabel.textAlignment = NSTextAlignmentCenter;
    contentLabel.backgroundColor = [UIColor clearColor];
    
    CAViewPaddingInfo paddingInfo = CAViewPaddingInfoCreate(8.f, 8.f, (title != nil) ? 0.f : 16.f, 20.f);
    
    
    
    self = [self initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Darkened bacground of the alert view overlay
    UIColor *bgColor = [UIColor colorWithWhite:0.0f alpha:0.30f];
    
    UIColor *alertViewBgColor = nil;
    UIColor *titleColor = nil;
    
    
    
    
    if (backgroundColor)    alertViewBgColor = backgroundColor;
    else                    alertViewBgColor = [UIColor colorWithWhite:0.0f alpha:0.8f];
    
    if (foregroundColor)    titleColor = foregroundColor;
    else                    titleColor = [UIColor whiteColor];
    
    
    UIColor *titleBgColor           = [UIColor colorWithWhite:0.0f alpha:0.0f];
    
    UIColor *cancelButtonBgColor    = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.9f];
    UIColor *confirmButtonBgColor   = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.9f];
    
    UIColor *cancelButtonTitleColor = [UIColor colorWithRed:0.2f green:0.2f blue:0.2f alpha:1.0f];
    UIColor *confirmButtonTitleColor= [UIColor colorWithRed:0.2f green:0.2f blue:0.2f alpha:1.0f];
    
    // UIColor *separatorViewColor     = [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:0.3f];
    UIFont *titleFont               = [UIFont boldSystemFontOfSize:16.0f];
    UIFont *buttonFont              = [UIFont systemFontOfSize:15.0f];
    

    mCustomView = contentLabel;
    
    mKeyboardAdjustType = VisibleCustomView;
    
    bool createCancelButton = !(cancelButtonText==nil || cancelButtonText.length < 1);
    bool createConfirmButton = !(confirmButtonText==nil || confirmButtonText.length < 1);
    bool createBothButtons = (createCancelButton && createConfirmButton);
    
    self.backgroundColor = bgColor;
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    float alertViewHeight = 0.0f;
    float alertViewWidth = 0.0f;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    CGSize titleTextSize = [title sizeWithFont:titleFont];
    CGSize cancelButtonTextSize = [cancelButtonText sizeWithFont:buttonFont];
    CGSize confirmButtonTextSize = [confirmButtonText sizeWithFont:buttonFont];
#pragma clang diagnostic pop
    
    float titleHeight = titleTextSize.height * 2.3f;
    float buttonsHeight = 0.0f;
    
    {
        float cancelButtonHeight = (createCancelButton) ? (cancelButtonTextSize.height * 2.4f) : 0.0f;
        float confirmButtonHeight = (createConfirmButton) ? (confirmButtonTextSize.height * 2.4f) : 0.0f;
        buttonsHeight = MAX(cancelButtonHeight, confirmButtonHeight);
    }
    
    mButtonsHeight = buttonsHeight;
    
    float middleViewHeight = 0.0f;
    
    float titleWidth = ( titleTextSize.width + 30.0f );
    float cancelButtonWidth = (createCancelButton) ? ( MAX(cancelButtonTextSize.width + 30.0f, confirmButtonTextSize.width + 30.0f ) ) : 0.0f;
    float confirmButtonWidth = (createConfirmButton) ? ( MAX(confirmButtonTextSize.width + 30.0f, cancelButtonTextSize.width + 30.0f ) ) : 0.0f;
    float buttonsWidth = cancelButtonWidth + confirmButtonWidth;
    if(createBothButtons) {
        buttonsWidth += 1; // additional 1 point for the separator
    }
    float middleViewWidth = 0.0f;
    
    middleViewHeight = mCustomView.frame.size.height;
    middleViewWidth = mCustomView.frame.size.width;
    
    middleViewHeight += paddingInfo.bottom + paddingInfo.top;
    
    float buttonPadding = 8.f;

    
    alertViewHeight = ( titleHeight + middleViewHeight + buttonsHeight + buttonPadding );
    alertViewWidth = MAX(MAX(titleWidth, (middleViewWidth+paddingInfo.left+paddingInfo.right)), buttonsWidth );
    
    
    if(buttonsWidth < alertViewWidth) {
        float widthLeftover = (alertViewWidth - buttonsWidth);
        if(createCancelButton) {
            cancelButtonWidth += ( createConfirmButton ) ? ( widthLeftover / 2.0f ) : widthLeftover;
        }
        if(createConfirmButton) {
            confirmButtonWidth += ( createCancelButton ) ? ( widthLeftover / 2.0f ) : widthLeftover;
        }
    }
    
    mAlertView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, alertViewWidth, alertViewHeight)];
    CGRect frame = mAlertView.frame;
    frame.origin.x = [self center].x - alertViewWidth / 2.0f;
    frame.origin.y = [self center].y - alertViewHeight / 2.0f;
    mAlertView.frame = frame;
    mAlertView.layer.cornerRadius = 10.0f;
    mAlertView.clipsToBounds = YES;
    mAlertView.backgroundColor = alertViewBgColor;
    

    if(createCancelButton)
    {
        mCancelButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f + buttonPadding, titleHeight + middleViewHeight, cancelButtonWidth - buttonPadding - (buttonPadding * 0.5f * (createConfirmButton ? 1 : 2)), buttonsHeight)];
        
        [mCancelButton setTitle:cancelButtonText forState:UIControlStateNormal];
        [mCancelButton setTitleColor:cancelButtonTitleColor forState:UIControlStateNormal];
        [mCancelButton setBackgroundColor:cancelButtonBgColor];
        [mCancelButton.titleLabel setFont:buttonFont];
        [mCancelButton addTarget:self action:@selector(_internalCancelCallback) forControlEvents:UIControlEventTouchUpInside];
        [[mCancelButton layer] setCornerRadius:5.0f];
    }
    
    if(createConfirmButton)
    {
        float x = ( createCancelButton ) ? ( cancelButtonWidth + 1.0f + (buttonPadding * 0.5f)) : buttonPadding;
        float widthAdjust = (!createCancelButton ? (buttonPadding * 0.5f) : 0.f);
        
        mConfirmButton = [[UIButton alloc] initWithFrame:CGRectMake(x, titleHeight + middleViewHeight, confirmButtonWidth - buttonPadding - (buttonPadding * 0.5f) - widthAdjust, buttonsHeight)];
        
        [mConfirmButton setTitle:confirmButtonText forState:UIControlStateNormal];
        [mConfirmButton setTitleColor:confirmButtonTitleColor forState:UIControlStateNormal];
        [mConfirmButton setBackgroundColor:confirmButtonBgColor];
        [mConfirmButton.titleLabel setFont:buttonFont];
        [mConfirmButton addTarget:self action:@selector(_internalConfirmCallback) forControlEvents:UIControlEventTouchUpInside];
        [[mConfirmButton layer] setCornerRadius:5.0f];
    }
    
    /*if(createBothButtons) {
        mButtonSeparatorView = [[UIView alloc] initWithFrame:CGRectMake(cancelButtonWidth, titleHeight + middleViewHeight, 1.0f, buttonsHeight)];
        [mButtonSeparatorView setBackgroundColor:separatorViewColor];
    }*/
    
    CGRect customViewFrame = mCustomView.frame;
    customViewFrame.origin.y = titleHeight + paddingInfo.top;
    customViewFrame.origin.x = (alertViewWidth / 2.0f) - (customViewFrame.size.width/2.0f);
    mCustomView.frame = customViewFrame;
    
    mTitle = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, alertViewWidth, titleHeight)];
    [mTitle setLineBreakMode:NSLineBreakByWordWrapping];
    [mTitle setNumberOfLines:2];
    [mTitle setFont:titleFont];
    [mTitle setText:title];
    [mTitle setTextColor:titleColor];
    [mTitle setBackgroundColor:titleBgColor];
    [mTitle setTextAlignment:NSTextAlignmentCenter];
    
    if(createCancelButton)[mAlertView addSubview:mCancelButton];
    if(createConfirmButton)[mAlertView addSubview:mConfirmButton];
    if(createBothButtons)[mAlertView addSubview:mButtonSeparatorView];
    if(mCustomView==nil) [mAlertView addSubview:mSpinner];
    else [mAlertView addSubview:mCustomView];
    [mAlertView addSubview:mTitle];
    
    [self addSubview:mAlertView];
    
    self.hidden = YES;
    
    return self;
}

// initialize with activity indicator
- (id)initWithTitle:(NSString *)_titleText withCancelButtonText:(NSString *)_cancelButtonText withConfirmButtonText:(NSString*)_confirmButtonText
{
    return [self initWithTitleText:_titleText withCancelButtonText:_cancelButtonText withCustomView:nil withPaddingInfo:CAViewPaddingInfoCreate(0.0f,0.0f,0.0f,0.0f) withConfirmButtonText:_confirmButtonText withMakeSquare:NO];
}

// initialize with custom view
- (id)initWithCustomView:(UIView *)_customView withTitleText:(NSString *)_titleText withCancelButtonText:(NSString *)_cancelButtonText withConfirmButtonText:(NSString *)_confirmButtonText
{
    return [self initWithTitleText:_titleText withCancelButtonText:_cancelButtonText withCustomView:_customView withPaddingInfo:CAViewPaddingInfoCreate(0.0f,0.0f,0.0f,0.0f) withConfirmButtonText:_confirmButtonText withMakeSquare:NO];
}

- (id)initWithCustomView:(UIView *)_customView withPaddingInfo:(CAViewPaddingInfo)_paddingInfo withTitleText:(NSString *)_titleText withCancelButtonText:(NSString *)_cancelButtonText withConfirmButtonText:(NSString *)_confirmButtonText
{
    return [self initWithTitleText:_titleText withCancelButtonText:_cancelButtonText withCustomView:_customView withPaddingInfo:_paddingInfo withConfirmButtonText:_confirmButtonText withMakeSquare:NO];
}

// initialize with activity indicator
- (id)initWithTitle:(NSString *)_titleText withCancelButtonText:(NSString *)_cancelButtonText withConfirmButtonText:(NSString *)_confirmButtonText withMakeSquare:(BOOL)makeSquare
{
    return [self initWithTitleText:_titleText withCancelButtonText:_cancelButtonText withCustomView:nil withPaddingInfo:CAViewPaddingInfoCreate(0.0f,0.0f,0.0f,0.0f) withConfirmButtonText:_confirmButtonText withMakeSquare:makeSquare];
}

// initialize with custom view
- (id)initWithCustomView:(UIView *)_customView withTitleText:(NSString *)_titleText withCancelButtonText:(NSString *)_cancelButtonText withConfirmButtonText:(NSString *)_confirmButtonText withMakeSquare:(BOOL)makeSquare
{
    return [self initWithTitleText:_titleText withCancelButtonText:_cancelButtonText withCustomView:_customView withPaddingInfo:CAViewPaddingInfoCreate(0.0f,0.0f,0.0f,0.0f) withConfirmButtonText:_confirmButtonText withMakeSquare:makeSquare];
}

- (id)initWithCustomView:(UIView *)_customView withPaddingInfo:(CAViewPaddingInfo)_paddingInfo withTitleText:(NSString *)_titleText withCancelButtonText:(NSString *)_cancelButtonText withConfirmButtonText:(NSString *)_confirmButtonText withMakeSquare:(BOOL)makeSquare 
{
    return [self initWithTitleText:_titleText withCancelButtonText:_cancelButtonText withCustomView:_customView withPaddingInfo:_paddingInfo withConfirmButtonText:_confirmButtonText withMakeSquare:makeSquare];
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification
{
    isKeyboardVisible = true;
    
    CGRect keyboardRect;
    [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardRect];
    mKeyboardEndFrame = keyboardRect;

    [self adjustForKeyboard];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    isKeyboardVisible = false;
    
    CGRect keyboardRect;
    [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardRect];
    
    [self layoutSubviewsWithAnimation];
}

- (void)adjustForKeyboard
{
    [UIView animateWithDuration:0.225f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        mAlertView.frame = [self alertViewFrameForAdjustingKeyboard];
    } completion:^(BOOL finished) {
        
    }];
    
}

- (CGRect)alertViewFrameForAdjustingKeyboard {
    
    UIInterfaceOrientation orientation = [self getRootViewController].interfaceOrientation;
    float keyboardY = 0.0f;
    
    if(UIInterfaceOrientationLandscapeLeft == orientation) {
        keyboardY = mKeyboardEndFrame.origin.x;
    }
    else if(UIInterfaceOrientationLandscapeRight == orientation) {
        keyboardY = [UIScreen mainScreen].bounds.size.width - mKeyboardEndFrame.size.width;
    }
    else if(UIInterfaceOrientationPortrait) {
        keyboardY = mKeyboardEndFrame.origin.y;
    }
    else if(UIInterfaceOrientationPortraitUpsideDown) {
        keyboardY = [UIScreen mainScreen].bounds.size.height - mKeyboardEndFrame.size.height;
    }
    
    float statusBarHeight = ([[UIApplication sharedApplication] statusBarFrame].size.height > 0.0f) ? 20.0f : 0.0f;
    keyboardY -= (mAlertView.frame.size.height + statusBarHeight) - mButtonsHeight;

    if(mKeyboardAdjustType == VisibleButtons)
        keyboardY -= mButtonsHeight / 2.0f + 6.0f;
    
    if(keyboardY < mAlertView.frame.origin.y) {
        CGRect newFrame = mAlertView.frame;
        newFrame.origin.y = keyboardY;
        return newFrame;
    }
    
    return mAlertView.frame;
}

#pragma mark - UIView

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)willRemoveSubview:(UIView *)subview
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - ALCustomAlertView

- (void)setCancelCallback:(SEL)_cancelCallback withTarget:(id)_target
{
    mCancelCallback = _cancelCallback;
    mCancelCallbackTarget = _target;
}

- (void)setConfirmCallback:(SEL)_confirmCallback withTarget:(id)_target
{
    mConfirmCallback = _confirmCallback;
    mConfirmCallbackTarget = _target;
}

- (void)changeFrameForOrientation:(UIInterfaceOrientation) orientation
{
    UIView *masterView = [[[[[UIApplication sharedApplication] delegate] window] rootViewController] view];

    if(UIInterfaceOrientationIsLandscape(orientation)) {
        CGRect frame = self.frame;
        frame.size.width = masterView.frame.size.height;
        frame.size.height = masterView.frame.size.width;
        self.frame = frame;
    }
}

- (void)showWithAnimation
{
    self.alpha = 0.0f;
    self.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    self.hidden = NO;
    [UIView animateWithDuration:0.15f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
                         self.alpha = 1.0f;
                     }
                     completion:^(BOOL finished) {
                         if(mDelegate!=nil && [mDelegate respondsToSelector:@selector(didShow:)]) [mDelegate didShow:self];
                     }];
}

- (void)hideWithAnimation {
    
    self.alpha = 1.0f;
    self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    self.hidden = NO;
    [UIView animateWithDuration:0.15f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.alpha = 0.0f;
                     }
                     completion:^(BOOL finished) {
                         self.hidden = YES;
                         [self removeFromSuperview];
                         if(mDelegate!=nil && [mDelegate respondsToSelector:@selector(didHide:)]) [mDelegate didHide:self];
                     }];
}

- (UIViewController *)getRootViewController
{
    return [[[[UIApplication sharedApplication] delegate] window] rootViewController];
}

- (void)show
{
    UIView *masterView;
    masterView = [[self getRootViewController] view];
    if(masterView == nil) {
        masterView = [[[UIApplication sharedApplication] delegate] window];
    }
    
    [self changeFrameForOrientation:[self getRootViewController].interfaceOrientation];
    
    if(mDelegate!=nil && [mDelegate respondsToSelector:@selector(willShow:)]) [mDelegate willShow:self];
    [masterView addSubview:self];
    [self showWithAnimation];
}

- (void)hide {
    if(mDelegate!=nil && [mDelegate respondsToSelector:@selector(willHide:)]) [mDelegate willHide:self];
    [self hideWithAnimation];
}

- (CGRect)alertViewFrameForLayoutSubviews
{
    CGRect frame = mAlertView.frame;
    frame.origin.x = [self center].x - mAlertView.frame.size.width / 2.0f;
    frame.origin.y = [self center].y - mAlertView.frame.size.height / 2.0f;
    return frame;
}

- (void)layoutSubviewsWithAnimation
{
    [UIView animateWithDuration:0.225f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
         mAlertView.frame = [self alertViewFrameForLayoutSubviews];
    } completion:^(BOOL finished) {
        
    }];
}

- (void)layoutSubviews
{
    mAlertView.frame = [self alertViewFrameForLayoutSubviews];
}

@end
