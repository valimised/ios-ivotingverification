//
//  UICustomAlertView.h
//  v 1.0

@class ALCustomAlertView;

@protocol ALCustomAlertViewDelegate <NSObject>
@optional
- (void) willHide:(ALCustomAlertView*)customAlertView;
- (void) didHide:(ALCustomAlertView*)customAlertView;
- (void) willShow:(ALCustomAlertView*)customAlertView;
- (void) didShow:(ALCustomAlertView*)customAlertView;
- (void) cancelButtonPressed:(ALCustomAlertView*)customAlertView;
- (void) confirmButtonPressed:(ALCustomAlertView*)customAlertView;
- (void) alertView:(ALCustomAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end


typedef struct CAViewPaddingInfo_tag {

    float left;
    float right;
    float top;
    float bottom;

} CAViewPaddingInfo;


CAViewPaddingInfo CAViewPaddingInfoCreate(float _left, float _right, float _top, float _bottom);

enum UICustomAlertViewKeyboardAdjustType {
    VisibleCustomView,
    VisibleButtons
};

const static NSString* kAlertViewMessage = @"message";
const static NSString* kAlertViewTitle = @"title";
const static NSString* kAlertViewCancelButtonTitle = @"cancelTitle";
const static NSString* kAlertViewConfrimButtonTitle = @"confirmTitle";
const static NSString* kAlertViewForegroundColor = @"FGColor";
const static NSString* kAlertViewBackgroundColor = @"BGColor";
const static float alertViewHeight = 265.f;
const static float alertViewWidth = 265.f;

@interface ALCustomAlertView : UIView
{
    UIButton*                    mCancelButton;
    UIButton*                    mConfirmButton;
    UILabel*                     mTitle;
    UIActivityIndicatorView*     mSpinner;
    UIView*                      mAlertView;
    UIView*                      mCustomView;
    float                       mButtonsHeight;
    id                          mCancelCallbackTarget;
    SEL                         mCancelCallback;
    id                          mConfirmCallbackTarget;
    SEL                         mConfirmCallback;
    CAViewPaddingInfo           mMiddleViewPadding;
    CGRect                      mKeyboardEndFrame;
    id<ALCustomAlertViewDelegate> mDelegate;
    enum UICustomAlertViewKeyboardAdjustType mKeyboardAdjustType;
}

@property (readonly, nonatomic, retain, getter = title) UILabel               * mTitle;
@property (readonly, nonatomic, retain, getter = cancelButton) UIButton       * mCancelButton;
@property (readonly, nonatomic, retain, getter = okButton) UIButton           * mConfirmButton;
@property (nonatomic, retain, getter = delegate,
           setter = setDelegate: ) id<ALCustomAlertViewDelegate> mDelegate;
@property (nonatomic, setter = setKeyboardAdjustmentType:,
           getter = keyboardAdjustmentType) enum UICustomAlertViewKeyboardAdjustType mKeyboardAdjustType;
@property (nonatomic, retain, readonly, getter = mainView) UIView             * mAlertView;

- (id) initWithOptions:(NSDictionary*)options;

// show with animation (scale + fade in)
- (void) show;
// hide with animation (fade out)
- (void) hide;
- (void) setCancelCallback:(SEL)_cancelCallback withTarget:(id)
    _target; // called when "Cancel" button pressed
- (void) setConfirmCallback:(SEL)_confirmCallback withTarget:(id)
    _target; // called when "Confirm" (OK) button is pressed

@end
