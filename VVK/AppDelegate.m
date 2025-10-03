//
//  AppDelegate.m
//  iVotingVerification

#import "AppDelegate.h"
#import "ScannerViewController.h"
#import "VoteVerificationResultsViewController.h"
#import "HelpViewController.h"
#import "UIColor+Hex.h"
#import "C.h"
#import "DoRotation.h"

#define TAG_GENERAL_ERROR 1000
#define TAG_CONFIGURATION_REQUEST_ERROR 1002
#define TAG_VERSION_ERROR 1003
#define TAG_BACKGROUND_OVERLAY 1004


@interface AppDelegate (NotificationObserver)
- (void) didLoadConfigurationFile;
@end


@implementation AppDelegate {
    NSObject* errorLock;
}

@synthesize currentVoteContainer;
@synthesize error;


- (BOOL) application:(UIApplication*)application didFinishLaunchingWithOptions:
    (NSDictionary*)launchOptions
{
    DLog(@"didFinishLaunchingWithOptions");
    error = NO;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    scannerViewController = [[ScannerViewController alloc] initWithNibName:@"ScannerViewController"
                                                           bundle:nil];
    voteVerificationResultsViewController = [[VoteVerificationResultsViewController alloc]
                                            initWithNibName:@"VoteVerificationResultsViewController" bundle:nil];
    helpViewController = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    resultContainerNavigationController = [[UINavigationController alloc] initWithRootViewController:
                                                                          voteVerificationResultsViewController];
    helpContainerNavigationController = [[UINavigationController alloc] initWithRootViewController:
                                                                        helpViewController];
    [self.window setRootViewController:scannerViewController];
    [self.window setBackgroundColor:[UIColor whiteColor]];
    [self.window makeKeyAndVisible];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              didLoadConfigurationFile) name:didLoadConfigurationFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
    backgroundStartTime = [[NSDate date] timeIntervalSince1970];
    [[Config sharedInstance] requestRemoteConfigurationFile];
    return YES;
}

- (void) orientationChanged:(NSNotification *)note
{
    UIDevice* device = note.object;
    [[DoRotation sharedInstance] changeFrameForOrientation:device.orientation forView:loaderContainer];
}

- (void) applicationWillResignActive:(UIApplication*)application
{
    backgroundStartTime = [[NSDate date] timeIntervalSince1970];
    [self appWillEnterBackground];
}

- (void) applicationDidEnterBackground:(UIApplication*)application
{
}

- (void) applicationWillEnterForeground:(UIApplication*)application
{
}

- (void) applicationDidBecomeActive:(UIApplication*)application
{
    [self appDidEnterForeground];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeInBackground = fabs(now - backgroundStartTime);
    DLog(@"timeInBackground = %f", timeInBackground);

    if (timeInBackground >= (15 * 60.f) && currentVoteContainer) {
        UIView *overlay = [self.window viewWithTag:TAG_VOTE_SIGNER_WINDOW];
        if (overlay) {
            [overlay removeFromSuperview];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:nil];
    }
}

- (void) applicationWillTerminate:(UIApplication*)application
{
}

- (void)appWillEnterBackground
{
    UIView *overlay = [[UIView alloc] initWithFrame:self.window.bounds];
    overlay.backgroundColor = [UIColor blackColor];
    overlay.tag = TAG_BACKGROUND_OVERLAY;
    [self.window addSubview:overlay];
}

- (void)appDidEnterForeground
{
    UIView *overlay = [self.window viewWithTag:TAG_BACKGROUND_OVERLAY];
    if (overlay) {
        [overlay removeFromSuperview];
    }
}


#pragma mark - Public methods

- (void) presentError:(in NSString*)errorMessage
{
    if (!error) {
        @synchronized (errorLock) {
            if (!error) {
                error = YES;
                DLog(@"%@", errorMessage);
                ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {
                    kAlertViewTitle:[[Config sharedInstance] errorMessageForKey:@"error_title_default"],
                    kAlertViewMessage:errorMessage,
                    kAlertViewConfrimButtonTitle:[[Config sharedInstance] textForKey:@"btn_ok"],
                    kAlertViewBackgroundColor:[[C sharedInstance] errorWindow],
                    kAlertViewForegroundColor:[[C sharedInstance] errorWindowForeground]
                }];
                [alert setDelegate:self];
                [alert setTag:TAG_GENERAL_ERROR];
                [alert show];
                currentVoteContainer = nil;
            }
        }
    }
}

- (void) handleConfigurationRequestError
{
    ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {
        kAlertViewTitle:[[Config sharedInstance] errorMessageForKey:@"error_title_default"],
        kAlertViewMessage:[[Config sharedInstance] errorMessageForKey:@"get_config_message"],
        kAlertViewConfrimButtonTitle:@"Proovi uuesti",
        kAlertViewBackgroundColor:[[C sharedInstance] errorWindow],
        kAlertViewForegroundColor:[[C sharedInstance] errorWindowForeground]
    }];
    [alert setDelegate:self];
    [alert setTag:TAG_CONFIGURATION_REQUEST_ERROR];
    [alert show];
}

- (void)handleNetworkError
{
    ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {
        kAlertViewTitle:@"Internetiühendus puudub",
        kAlertViewMessage:[[Config sharedInstance] errorMessageForKey:@"no_network_message"],
        kAlertViewConfrimButtonTitle:@"Proovi uuesti",
        kAlertViewBackgroundColor:[[C sharedInstance] errorWindow],
        kAlertViewForegroundColor:[[C sharedInstance] errorWindowForeground]
    }];
    [alert setDelegate:self];
    [alert setTag:TAG_CONFIGURATION_REQUEST_ERROR];
    [alert show];
}

- (void) handleVersionError
{
    ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {
        kAlertViewTitle:[[Config sharedInstance] errorMessageForKey:@"error_title_bad_version"],
        kAlertViewMessage:[[Config sharedInstance] errorMessageForKey:@"bad_version_message"],
        kAlertViewConfrimButtonTitle:[[Config sharedInstance] textForKey:@"btn_ok"],
        kAlertViewBackgroundColor:[[C sharedInstance] errorWindow],
        kAlertViewForegroundColor:[[C sharedInstance] errorWindowForeground]
    }];
    [alert setDelegate:self];
    [alert setTag:TAG_VERSION_ERROR];
    [alert show];
}



- (void) presentVoteVerificationResults:(in NSDictionary*)results
{
    DLog(@"");
    [voteVerificationResultsViewController handleResults:results];
    resultContainerNavigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.window.rootViewController presentViewController:resultContainerNavigationController animated:
                                   YES completion:^ {

                                   }];
}


- (void) presentHelpScreen
{
    helpContainerNavigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.window.rootViewController presentViewController:helpContainerNavigationController animated:YES
                                   completion:^ {

                                   }];
}

- (void) showLoaderWithClearStyle:(BOOL)clearStyle
{
    const float loaderSize = 175.0f;
    CGRect screenBounds = [[UIScreen screens][0] bounds];
    CGRect loaderRect = CGRectMake((screenBounds.size.width - loaderSize) * 0.5f,
                                   (screenBounds.size.height - loaderSize) * 0.5f, loaderSize, loaderSize);
    loaderBG = [[UIView alloc] initWithFrame:screenBounds];
    loaderBG.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    loaderContainer = [[UIView alloc] initWithFrame:loaderRect];

    if (clearStyle == NO) {
        loaderContainer.backgroundColor = [[C sharedInstance] mainWindow];
    }
    else {
        loaderContainer.backgroundColor = [UIColor clearColor];
    }

    [loaderContainer.layer setCornerRadius:16.0];
    CGRect spinnerRect = loaderContainer.bounds;

    if (clearStyle == NO) {
        spinnerRect.size.height -= 30.f;
    }

    UIImageView* spinner = [[UIImageView alloc] initWithFrame:spinnerRect];
    spinner.image = [UIImage imageNamed:@"spinner.png"];
    spinner.contentMode = UIViewContentModeCenter;
    [loaderContainer addSubview:spinner];
    CABasicAnimation* fullRotation;
    fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    fullRotation.fromValue = [NSNumber numberWithFloat:0];
    fullRotation.toValue = [NSNumber numberWithFloat:((360 * M_PI) / 180)];
    fullRotation.duration = 2;
    fullRotation.repeatCount = 99;
    [spinner.layer addAnimation:fullRotation forKey:@"360"];

    if (clearStyle == NO) {
        UILabel* loaderText = [[UILabel alloc] initWithFrame:CGRectMake(0, loaderSize - 60, loaderSize,
                                               60)];
        loaderText.backgroundColor = [UIColor clearColor];
        loaderText.text = [[Config sharedInstance] textForKey:@"loading"];
        loaderText.textAlignment = NSTextAlignmentCenter;
        loaderText.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:18.0];
        loaderText.textColor = [[C sharedInstance] mainWindowForeground];
        [loaderContainer addSubview:loaderText];
    }

    [[DoRotation sharedInstance] rotateViewIfNeeded:loaderContainer];
    [self.window addSubview:loaderBG];
    [loaderBG addSubview:loaderContainer];
    loaderBG.alpha = 0.0f;
    loaderBG.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    [UIView animateWithDuration:0.2f animations:^ {
               self->loaderBG.alpha = 1.0f;
               self->loaderBG.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    }];
}

- (void) hideLoader
{
    loaderBG.alpha = 1.0f;
    loaderBG.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    [UIView animateWithDuration:0.2f animations:^ {
               self->loaderBG.alpha = 0.0f;
               self->loaderBG.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    } completion: ^ (BOOL finished) {
        [self->loaderBG removeFromSuperview];
        self->loaderBG = nil;
    }];
}


#pragma mark - Private methods

- (void) didLoadConfigurationFile
{
    UIColor* navBarColor = [[C sharedInstance] mainWindow];
    [[UINavigationBar appearance] setTitleTextAttributes:@ {
                             NSForegroundColorAttributeName:[[C sharedInstance] mainWindowForeground]
                                 }];
    [[UINavigationBar appearance] setBarTintColor:navBarColor];
    resultContainerNavigationController.navigationBar.tintColor = [[C sharedInstance] mainWindowForeground];
    helpContainerNavigationController.navigationBar.backgroundColor = navBarColor;
}

#pragma mark - Custom alert view delegate

- (void) alertView:(ALCustomAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Closing an error message
    if (alertView.tag == TAG_GENERAL_ERROR && buttonIndex == 1) {
        error = NO;

        if ([voteVerificationResultsViewController presentedModally]) {
            [resultContainerNavigationController dismissViewControllerAnimated:YES completion:nil];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:nil];
    }

    // Retry configuration loading
    if (alertView.tag == TAG_CONFIGURATION_REQUEST_ERROR && buttonIndex == 1) {
        [[Config sharedInstance] requestRemoteConfigurationFile];
    }

    if (alertView.tag == TAG_VERSION_ERROR) {
        NSString *iTunesLink = @"https://apps.apple.com/us/app/eh-kontrollrakendus/id1265172086?uo=4";
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink] options:@{} completionHandler:nil];
        [[Config sharedInstance] requestRemoteConfigurationFile];
    }
}

@end
