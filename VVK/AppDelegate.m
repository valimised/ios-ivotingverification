//
//  AppDelegate.m
//  iVotingVerification

#import "AppDelegate.h"
#import "ScannerViewController.h"
#import "VoteVerificationResultsViewController.h"
#import "HelpViewController.h"
#import "UIColor+Hex.h"

#define TAG_GENERAL_ERROR 1000
#define TAG_CONFIGURATION_REQUEST_ERROR 1002
#define TAG_VERSION_ERROR 1003


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
    resultContainerNavigationController.navigationBar.translucent = NO;
    helpContainerNavigationController.navigationBar.translucent = NO;
    [self.window setRootViewController:scannerViewController];
    [self.window setBackgroundColor:[UIColor whiteColor]];
    [self.window makeKeyAndVisible];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              didLoadConfigurationFile) name:didLoadConfigurationFile object:nil];
    backgroundStartTime = [[NSDate date] timeIntervalSince1970];
    [[Config sharedInstance] requestRemoteConfigurationFile];
    return YES;
}

- (void) applicationWillResignActive:(UIApplication*)application
{
    backgroundStartTime = [[NSDate date] timeIntervalSince1970];
}

- (void) applicationDidEnterBackground:(UIApplication*)application
{
}

- (void) applicationWillEnterForeground:(UIApplication*)application
{
}

- (void) applicationDidBecomeActive:(UIApplication*)application
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeInBackground = fabs(now - backgroundStartTime);
    DLog(@"timeInBackground = %f", timeInBackground);

    if (timeInBackground >= (15 * 60.f) && !currentVoteContainer) {
        [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:
                                              nil];
    }
}

- (void) applicationWillTerminate:(UIApplication*)application
{
}


#pragma mark - Public methods

- (void) presentError:(in NSString*)errorMessage
{
    if (!error) {
        @synchronized (errorLock) {
            if (!error) {
                error = YES;
                DLog(@"%@", errorMessage);
                ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewMessage:errorMessage,
                                                                      kAlertViewConfrimButtonTitle:[[Config sharedInstance] textForKey:@"btn_next"],
                                                                      kAlertViewBackgroundColor:[[Config sharedInstance] colorForKey:@"error_window"],
                                                                      kAlertViewForegroundColor:[[Config sharedInstance] colorForKey:@"error_window_foreground"]
                                                                                        }];
                [alert setDelegate:self];
                [alert setTag:TAG_GENERAL_ERROR];
                [alert show];
                currentVoteContainer = nil;
            }
        }
    }
}

- (void) presentDefaultError:(in NSString*)errorMessage
{
    if (!error) {
        @synchronized (errorLock) {
            if (!error) {
                error = YES;
                DLog(@"%@", errorMessage);
                ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewTitle:@"Viga",
                                                                      kAlertViewMessage:errorMessage,
                                                                      kAlertViewBackgroundColor:[UIColor colorWithHexString:@"#FF0000"],
                                                                      kAlertViewForegroundColor:[UIColor colorWithHexString:@"#FFFFFF"]
                                                                                        }];
                [alert setDelegate:self];
                [alert show];
            }
        }
    }
}


- (void) handleConfigurationRequestError
{
    ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewTitle:@"Viga",
                                                          kAlertViewMessage:@"Konfiguratsiooni laadimine ebaõnnestus.",
                                                          kAlertViewConfrimButtonTitle:@"Proovi uuesti",
                                                          kAlertViewBackgroundColor:[UIColor colorWithHexString:@"#FF0000"],
                                                          kAlertViewForegroundColor:[UIColor colorWithHexString:@"#FFFFFF"]
                                                                            }];
    [alert setDelegate:self];
    [alert setTag:TAG_CONFIGURATION_REQUEST_ERROR];
    [alert show];
}

- (void) handleVersionError
{
    ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {
                                                        kAlertViewMessage:[[Config sharedInstance] errorMessageForKey:@"bad_version_message"],
                                             kAlertViewConfrimButtonTitle:[[Config sharedInstance] textForKey:@"btn_next"],
                                                kAlertViewBackgroundColor:[[Config sharedInstance] colorForKey:@"error_window"],
                                                kAlertViewForegroundColor:[[Config sharedInstance] colorForKey:@"error_window_foreground"]
                                                                                        }];
    [alert setDelegate:self];
    [alert setTag:TAG_VERSION_ERROR];
    [alert show];
}



- (void) presentVoteVerificationResults:(in NSDictionary*)results
{
    DLog(@"");
    [voteVerificationResultsViewController handleResults:results];
    [self.window.rootViewController presentViewController:resultContainerNavigationController animated:
                                   YES completion:^ {

                                   }];
}


- (void) presentHelpScreen
{
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
    UIView* loaderContainer = [[UIView alloc] initWithFrame:loaderRect];

    if (clearStyle == NO) {
        loaderContainer.backgroundColor = [[Config sharedInstance] colorForKey:@"main_window"];
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
        loaderText.textColor = [[Config sharedInstance] colorForKey:@"main_window_foreground"];
        [loaderContainer addSubview:loaderText];
    }

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
    UIColor* navBarColor = [[Config sharedInstance] colorForKey:@"main_window"];
    [[UINavigationBar appearance] setTitleTextAttributes:@ {
                             NSForegroundColorAttributeName:[[Config sharedInstance] colorForKey:@"main_window_foreground"]
                                 }];
    [[UINavigationBar appearance] setBarTintColor:navBarColor];
    resultContainerNavigationController.navigationBar.tintColor = [[Config sharedInstance] colorForKey:
                                    @"main_window_foreground"];
    helpContainerNavigationController.navigationBar.tintColor = [[Config sharedInstance] colorForKey:
                                    @"main_window_foreground"];
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

        [scannerViewController setScannerEnabled:YES];
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
