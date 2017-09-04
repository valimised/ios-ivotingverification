//
//  AppDelegate.h
//  iVotingVerification

#import <UIKit/UIKit.h>

#import "ALCustomAlertView.h"

@class ScannerViewController;
@class VoteVerificationResultsViewController;
@class HelpViewController;
@class VoteContainer;

@interface AppDelegate : UIResponder <UIApplicationDelegate, ALCustomAlertViewDelegate>
{
    __strong ScannerViewController * scannerViewController;
    __strong VoteVerificationResultsViewController * voteVerificationResultsViewController;
    __strong HelpViewController * helpViewController;
    
    __strong UINavigationController * resultContainerNavigationController;
    __strong UINavigationController * helpContainerNavigationController;
    
    @private
    VoteContainer * currentVoteContainer;
    UIView * loaderBG;
    NSTimeInterval backgroundStartTime;
}

#pragma mark - Properties

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) VoteContainer * currentVoteContainer;


#pragma mark - Public methods

- (void)presentHelpScreen;

- (void)presentError:(in NSString *)errorMessage;

- (void)presentVoteVerificationResults:(in NSDictionary *)results;

- (void)showLoaderWithClearStyle:(BOOL)clearStyle;

- (void)hideLoader;

@end
