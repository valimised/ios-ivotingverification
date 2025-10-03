//
//  UICustomAlertView.m
//  v 1.0

#import "ALCustomAlertView.h"
#import "DoRotation.h"
#import <QuartzCore/QuartzCore.h>
#import "ScaledFonts.h"

#define IS_IPAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@implementation ALCustomAlertView

//static const float kCustomAlertViewMinWidth = 160.0f;
static bool isKeyboardVisible = false;

@synthesize mTitle;
@synthesize mCancelButton;
@synthesize mConfirmButton;
@synthesize mDelegate;
@synthesize mKeyboardAdjustType;
@synthesize mAlertView;

CAViewPaddingInfo CAViewPaddingInfoCreate(float _left, float _right, float _top, float _bottom)
{
    CAViewPaddingInfo result;
    result.top      = _top;
    result.bottom   = _bottom;
    result.left     = _left;
    result.right    = _right;
    return result;
}

#pragma mark - Internal methods

- (void) _internalCancelCallback
{
    if (mDelegate && [mDelegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
        [mDelegate alertView:self clickedButtonAtIndex:0];
    }

    if (mDelegate != nil && [mDelegate respondsToSelector:@selector(cancelButtonPressed:)]) {
        [mDelegate cancelButtonPressed:self];
    }

    if (mCancelCallbackTarget != nil && mCancelCallback != nil &&
            [mCancelCallbackTarget respondsToSelector:mCancelCallback]) {
        [mCancelCallbackTarget performSelector:mCancelCallback];
    }

    [self hide];
}

- (void) _internalConfirmCallback
{
    if (mDelegate && [mDelegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
        [mDelegate alertView:self clickedButtonAtIndex:1];
    }

    if (mDelegate != nil && [mDelegate respondsToSelector:@selector(confirmButtonPressed:)]) {
        [mDelegate confirmButtonPressed:self];
    }

    [self hide];
}

#pragma mark - Init methods

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {
        // Initialization code
    }

    return self;
}

- (id) initWithOptions:(NSDictionary*)options
{
    self = [self initWithFrame:[[UIScreen mainScreen] bounds]];

    NSString* message = options[kAlertViewMessage];
    NSString* title = options[kAlertViewTitle];
    NSString* cancelButtonText = options[kAlertViewCancelButtonTitle];
    NSString* confirmButtonText = options[kAlertViewConfrimButtonTitle];
    UIColor* foregroundColor = options[kAlertViewForegroundColor];
    UIColor* backgroundColor = options[kAlertViewBackgroundColor];
    UIColor* textColor = foregroundColor ?: [UIColor whiteColor];
    // Darkened bacground of the alert view overlay
    UIColor* bgColor = [UIColor colorWithWhite:0.0f alpha:0.30f];
    UIColor* alertViewBgColor = backgroundColor ?: [UIColor colorWithWhite:0.0f alpha:0.8f];
    UIFont* titleFont = [UIFont boldSystemFontOfSize:20.0f];
    UIFont* messageFont = [UIFont systemFontOfSize:16.0f];

    CAViewPaddingInfo paddingInfo = CAViewPaddingInfoCreate(8.f, 8.f, 8.f, 8.f);
    float contentWidth = alertViewWidth - paddingInfo.left - paddingInfo.right;

    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, contentWidth, 0)];
    mCustomView = [self scaledLabel:[[UILabel alloc] initWithFrame:label.frame] withFont:messageFont withText:message withColor:textColor];
    if (title != nil) {
        mTitle = [self scaledLabel:[[UILabel alloc] initWithFrame:label.frame] withFont:titleFont withText:title withColor:textColor];
    }

    self.backgroundColor = bgColor;
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

    mKeyboardAdjustType = VisibleCustomView;
    bool createCancelButton = !(cancelButtonText == nil || cancelButtonText.length < 1);
    bool createConfirmButton = !(confirmButtonText == nil || confirmButtonText.length < 1);
    bool createBothButtons = (createCancelButton && createConfirmButton);

    float titleHeight = mTitle.frame.size.height;
    mButtonsHeight = 48.f;
    float middleViewHeight = 180.f + paddingInfo.bottom + paddingInfo.top - mTitle.frame.size.height;

    float cancelButtonWidth = (createCancelButton) ? (alertViewWidth / 2) - paddingInfo.left - paddingInfo.right : 0.0f;
    float confirmButtonWidth = (createConfirmButton) ? (alertViewWidth / 2) - paddingInfo.left - paddingInfo.right : 0.0f;
    float buttonsWidth = cancelButtonWidth + confirmButtonWidth;

    if (createBothButtons) {
        buttonsWidth += 1; // additional 1 point for the separator
    }

    float buttonPadding = 8.f;

    if (buttonsWidth < alertViewWidth) {
        float widthLeftover = (alertViewWidth - buttonsWidth);

        if (createCancelButton) {
            cancelButtonWidth += ( createConfirmButton ) ? ( widthLeftover / 2.0f ) : widthLeftover;
        }

        if (createConfirmButton) {
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

    if (createCancelButton) {
        mCancelButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f + buttonPadding,
                                          titleHeight + middleViewHeight,
                                          cancelButtonWidth - buttonPadding - (buttonPadding * 0.5f * (createConfirmButton ? 1 : 2)),
                                          mButtonsHeight)];
        [self setupButton:mCancelButton withText:cancelButtonText withAction:@selector(_internalCancelCallback)];
    }

    if (createConfirmButton) {
        float x = ( createCancelButton ) ? ( cancelButtonWidth + 1.0f + (buttonPadding * 0.5f)) :
                  buttonPadding;
        float widthAdjust = (!createCancelButton ? (buttonPadding * 0.5f) : 0.f);
        mConfirmButton = [[UIButton alloc] initWithFrame:CGRectMake(x, titleHeight + middleViewHeight,
                                           confirmButtonWidth - buttonPadding - (buttonPadding * 0.5f) - widthAdjust, mButtonsHeight)];
        [self setupButton:mConfirmButton withText:confirmButtonText withAction:@selector(_internalConfirmCallback)];
    }

    CGRect customViewFrame = mCustomView.frame;
    customViewFrame.origin.y = titleHeight + paddingInfo.top;
    customViewFrame.origin.x = (alertViewWidth / 2.0f) - (customViewFrame.size.width / 2.0f);
    mCustomView.frame = customViewFrame;

    if (createCancelButton) {
        [mAlertView addSubview:mCancelButton];
    }

    if (createConfirmButton) {
        [mAlertView addSubview:mConfirmButton];
    }

    if (mCustomView == nil) {
        [mAlertView addSubview:mSpinner];
    }
    else {
        float scrollViewHeight = alertViewHeight - paddingInfo.top - paddingInfo.bottom - mButtonsHeight - 2*buttonPadding - 5.f;
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 10, alertViewWidth, scrollViewHeight)];
        if (UIAccessibilityIsVoiceOverRunning() || mCustomView.frame.size.height > 200) {
            mCustomView.accessibilityRespondsToUserInteraction = true;
        }
        if (mTitle != nil) {
            [scrollView addSubview: mTitle];
            CGFloat dividerY = CGRectGetMaxY(mTitle.frame) + paddingInfo.top;
            UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(paddingInfo.left, dividerY, contentWidth, 1.0f)];
            divider.backgroundColor = UIColor.whiteColor;
            [scrollView addSubview: divider];
            CGFloat customViewY = CGRectGetMaxY(divider.frame) + paddingInfo.top;
            CGRect customFrame = mCustomView.frame;
            customFrame.origin.y = customViewY;
            mCustomView.frame = customFrame;
        }
        [scrollView addSubview: mCustomView];
        scrollView.contentSize = CGSizeMake(contentWidth, mTitle.frame.size.height + mCustomView.frame.size.height * 1.1);
        scrollView.bounces = NO;
        scrollView.backgroundColor = [UIColor clearColor];
        [mAlertView addSubview:scrollView];
    }

    [self addSubview:mAlertView];
    self.hidden = YES;
    [[ScaledFonts sharedInstance] applyScaledFontToSubviewsOfView:mAlertView];
    return self;
}

# pragma mark - Private methods

- (UILabel*) scaledLabel:(UILabel*)label withFont:(UIFont*)font withText:(NSString*)text withColor:(UIColor*) textColor
{
    label.font = font;
    [[ScaledFonts sharedInstance] applyScaledFontToUILabel:(UILabel*)label];
    NSAttributedString* attributedText =
        [[NSAttributedString alloc] initWithString:text
                                    attributes:@ {NSFontAttributeName:label.font}];
    CGRect rect = [attributedText boundingRectWithSize:(CGSize) {
                       label.bounds.size.width, MAXFLOAT
                   }
                   options: NSStringDrawingUsesLineFragmentOrigin
                   context: nil];
    CGSize textSize = rect.size;
    CGRect labelFrame = CGRectMake(0, 0, label.bounds.size.width, textSize.height);

    label.text = text;
    label.frame = labelFrame;
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = textColor;
    return label;
}

- (void) setupButton:(UIButton*)button withText:(NSString*)text withAction:(SEL)action
{
    UIColor* buttonBgColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.9f];
    UIColor* buttonTitleColor = [UIColor colorWithRed:0.2f green:0.2f blue:0.2f alpha:1.0f];
    UIFont* buttonFont = [UIFont systemFontOfSize:15.0f];
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitleColor:buttonTitleColor forState:UIControlStateNormal];
    [button setBackgroundColor:buttonBgColor];
    [button.titleLabel setFont:buttonFont];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [[button layer] setCornerRadius:5.0f];
}

- (CGFloat)heightForText:(NSString *)text
                    font:(UIFont *)font {
    if (text.length == 0 || font == nil) return 0;

    UIFont *scaledFont = [[UIFontMetrics defaultMetrics] scaledFontForFont:font];
    NSDictionary *attributes = @{ NSFontAttributeName: scaledFont };

    CGSize maxSize = CGSizeMake(260, CGFLOAT_MAX);
    CGRect boundingRect = [text boundingRectWithSize:maxSize
                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:attributes
                                              context:nil];

    return ceil(boundingRect.size.height);
}

#pragma mark - Keyboard

- (void) keyboardWillShow:(NSNotification*)notification
{
    isKeyboardVisible = true;
    CGRect keyboardRect;
    [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardRect];
    mKeyboardEndFrame = keyboardRect;
    [self adjustForKeyboard];
}

- (void) keyboardWillHide:(NSNotification*)notification
{
    isKeyboardVisible = false;
    CGRect keyboardRect;
    [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardRect];
    [self layoutSubviewsWithAnimation];
}

- (void) adjustForKeyboard
{
    [UIView animateWithDuration:0.225f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:
           ^ {
               self->mAlertView.frame = [self alertViewFrameForAdjustingKeyboard];
           } completion: ^ (BOOL finished) {
    }];
}

- (CGRect) alertViewFrameForAdjustingKeyboard
{
    UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;
    CGRect statusBarFrame = CGRectZero;

    NSSet<UIScene *> *connectedScenes =  [UIApplication sharedApplication].connectedScenes;
    for (UIScene *scene in connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            orientation = windowScene.interfaceOrientation;
            statusBarFrame = windowScene.statusBarManager.statusBarFrame;
            break;
        }
    }

    float keyboardY = 0.0f;

    if (UIInterfaceOrientationLandscapeLeft == orientation) {
        keyboardY = mKeyboardEndFrame.origin.x;
    }
    else if (UIInterfaceOrientationLandscapeRight == orientation) {
        keyboardY = [UIScreen mainScreen].bounds.size.width - mKeyboardEndFrame.size.width;
    }
    else if (UIInterfaceOrientationPortrait == orientation) {
        keyboardY = mKeyboardEndFrame.origin.y;
    }
    else {
        keyboardY = [UIScreen mainScreen].bounds.size.height - mKeyboardEndFrame.size.height;
    }

    float statusBarHeight = (statusBarFrame.size.height > 0.0f) ? 20.0f : 0.0f;
    keyboardY -= (mAlertView.frame.size.height + statusBarHeight) - mButtonsHeight;

    if (mKeyboardAdjustType == VisibleButtons) {
        keyboardY -= mButtonsHeight / 2.0f + 6.0f;
    }

    if (keyboardY < mAlertView.frame.origin.y) {
        CGRect newFrame = mAlertView.frame;
        newFrame.origin.y = keyboardY;
        return newFrame;
    }

    return mAlertView.frame;
}

#pragma mark - UIView

- (void) willMoveToSuperview:(UIView*)newSuperview
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
}

- (void) willRemoveSubview:(UIView*)subview
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - ALCustomAlertView

- (void) setCancelCallback:(SEL)_cancelCallback withTarget:(id)_target
{
    mCancelCallback = _cancelCallback;
    mCancelCallbackTarget = _target;
}

- (void) setConfirmCallback:(SEL)_confirmCallback withTarget:(id)_target
{
    mConfirmCallback = _confirmCallback;
    mConfirmCallbackTarget = _target;
}

- (void) orientationChanged:(NSNotification*)note
{
    UIDevice* device = note.object;
    [[DoRotation sharedInstance] changeFrameForOrientation:device.orientation forView:mAlertView];
}

- (void) showWithAnimation
{
    self.alpha = 0.0f;
    self.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    self.hidden = NO;
    [UIView animateWithDuration:0.15f
            delay:0.0f
            options:UIViewAnimationOptionCurveEaseOut
           animations:^ {
               self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
               self.alpha = 1.0f;
           }
           completion: ^ (BOOL finished) {
        if (self->mDelegate != nil && [self->mDelegate respondsToSelector:@selector(didShow:)]) {
            [self->mDelegate didShow:self];
        }
    }];
}

- (void) hideWithAnimation
{
    self.alpha = 1.0f;
    self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    self.hidden = NO;
    [UIView animateWithDuration:0.15f
            delay:0.0f
            options:UIViewAnimationOptionCurveEaseOut
           animations:^ {
               self.alpha = 0.0f;
           }
           completion: ^ (BOOL finished) {
        self.hidden = YES;
        [self removeFromSuperview];

        if (self->mDelegate != nil && [self->mDelegate respondsToSelector:@selector(didHide:)]) {
            [self->mDelegate didHide:self];
        }
    }];
}

- (UIViewController*) getRootViewController
{
    return [[[[UIApplication sharedApplication] delegate] window] rootViewController];
}

- (void) show
{
    UIView* masterView;
    masterView = [[self getRootViewController] view];

    if (masterView == nil) {
        masterView = [[[UIApplication sharedApplication] delegate] window];
    }

    if (mDelegate != nil && [mDelegate respondsToSelector:@selector(willShow:)]) {
        [mDelegate willShow:self];
    }

    [masterView addSubview:self];
    [self showWithAnimation];
    [[DoRotation sharedInstance] rotateViewIfNeeded:mAlertView];
}

- (void) hide
{
    if (mDelegate != nil && [mDelegate respondsToSelector:@selector(willHide:)]) {
        [mDelegate willHide:self];
    }

    [self hideWithAnimation];
}

- (CGRect) alertViewFrameForLayoutSubviews
{
    CGRect frame = mAlertView.frame;
    frame.origin.x = [self center].x - mAlertView.frame.size.width / 2.0f;
    frame.origin.y = [self center].y - mAlertView.frame.size.height / 2.0f;
    return frame;
}

- (void) layoutSubviewsWithAnimation
{
    [UIView animateWithDuration:0.225f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:
           ^ {
               self->mAlertView.frame = [self alertViewFrameForLayoutSubviews];
           } completion: ^ (BOOL finished) {
    }];
}

- (void) layoutSubviews
{
    mAlertView.frame = [self alertViewFrameForLayoutSubviews];
}

@end
