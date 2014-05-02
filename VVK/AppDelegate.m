//
//  AppDelegate.m
//  iVotingVerification
//
//  Created by Eigen Lenk on 1/27/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "AppDelegate.h"
#import "ScannerViewController.h"
#import "VoteVerificationResultsViewController.h"
#import "HelpViewController.h"


@interface AppDelegate (NotificationObserver)
- (void)didLoadConfigurationFile;
@end


@implementation AppDelegate

@synthesize currentVoteContainer;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    scannerViewController = [[ScannerViewController alloc] initWithNibName:@"ScannerViewController" bundle:nil];
    voteVerificationResultsViewController = [[VoteVerificationResultsViewController alloc] initWithNibName:@"VoteVerificationResultsViewController" bundle:nil];
    helpViewController = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    resultContainerNavigationController = [[UINavigationController alloc] initWithRootViewController:voteVerificationResultsViewController];
    helpContainerNavigationController = [[UINavigationController alloc] initWithRootViewController:helpViewController];
    
    if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 7.0)
    {
        resultContainerNavigationController.navigationBar.translucent = NO;
        helpContainerNavigationController.navigationBar.translucent = NO;
    }
    
    [self.window setRootViewController:scannerViewController];
    [self.window setBackgroundColor:[UIColor whiteColor]];
    [self.window makeKeyAndVisible];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLoadConfigurationFile) name:didLoadConfigurationFile object:nil];
    
    backgroundStartTime = [[NSDate date] timeIntervalSince1970];
    
    [[Config sharedInstance] requestRemoteConfigurationFile];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    backgroundStartTime = [[NSDate date] timeIntervalSince1970];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{

}

- (void)applicationWillEnterForeground:(UIApplication *)application
{

}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeInBackground = fabsf(now - backgroundStartTime);
    
    DLog(@"timeInBackground = %f", timeInBackground);
    
    if (timeInBackground >= (15 * 60.f) && !currentVoteContainer)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:nil];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{

}


#pragma mark - Public methods

- (void)presentError:(in NSString *)errorMessage
{
    DLog(@"presentError: %@", errorMessage);
    
    ALCustomAlertView * alert = [[ALCustomAlertView alloc] initWithOptions:@{kAlertViewMessage: errorMessage,
                                                                             kAlertViewConfrimButtonTitle: [[Config sharedInstance] textForKey:@"btn_next"],
                                                                             kAlertViewBackgroundColor: [[Config sharedInstance] colorForKey:@"error_window"],
                                                                             kAlertViewForegroundColor: [[Config sharedInstance] colorForKey:@"error_window_foreground"]}];
    
    [alert setDelegate:self];
    [alert setTag:1000];
    [alert show];
    
    [self setCurrentVoteContainer:nil];
}

- (void)presentVoteVerificationResults:(in NSArray *)results
{
    DLog(@"presentVoteVerificationResults");
    
    [voteVerificationResultsViewController handleResults:results];
    
    [self.window.rootViewController presentViewController:resultContainerNavigationController animated:YES completion:^{
        
    }];
}

- (void)presentHelpScreen
{
    [self.window.rootViewController presentViewController:helpContainerNavigationController animated:YES completion:^{
        
    }];
}

- (void)showLoaderWithClearStyle:(BOOL)clearStyle
{
    const float loaderSize = 175.0f;
    CGRect screenBounds = [[UIScreen screens][0] bounds];
    CGRect loaderRect = CGRectMake((screenBounds.size.width - loaderSize) * 0.5f, (screenBounds.size.height - loaderSize) * 0.5f, loaderSize, loaderSize);
    
    
    loaderBG = [[UIView alloc] initWithFrame:screenBounds];
    loaderBG.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    
    
    UIView * loaderContainer = [[UIView alloc] initWithFrame:loaderRect];
    
    if (clearStyle == NO)
    {
        loaderContainer.backgroundColor = [[Config sharedInstance] colorForKey:@"main_window"];
    }
    else
    {
        loaderContainer.backgroundColor = [UIColor clearColor];
    }
    
    [loaderContainer.layer setCornerRadius:16.0];
    
    CGRect spinnerRect = loaderContainer.bounds;
    
    if (clearStyle == NO) {
        spinnerRect.size.height -= 30.f;
    }
    
    UIImageView * spinner = [[UIImageView alloc] initWithFrame:spinnerRect];
    spinner.image = [UIImage imageNamed:@"spinner.png"];
    spinner.contentMode = UIViewContentModeCenter;
    [loaderContainer addSubview:spinner];
    
    CABasicAnimation *fullRotation;
	fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
	fullRotation.fromValue = [NSNumber numberWithFloat:0];
	fullRotation.toValue = [NSNumber numberWithFloat:((360*M_PI)/180)];
	fullRotation.duration = 2;
	fullRotation.repeatCount = 99;
	
	[spinner.layer addAnimation:fullRotation forKey:@"360"];
    
    
    
    if (clearStyle == NO)
    {
        UILabel * loaderText = [[UILabel alloc] initWithFrame:CGRectMake(0, loaderSize - 60, loaderSize, 60)];
        loaderText.backgroundColor = [UIColor clearColor];
        loaderText.text = [[Config sharedInstance] textForKey:@"loading"];
        loaderText.textAlignment = NSTextAlignmentCenter;
        
        if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 7.0)
        {
            loaderText.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:18.0];
        }
        else
        {
            loaderText.font = [UIFont systemFontOfSize:18.0];
        }
        
        loaderText.textColor = [[Config sharedInstance] colorForKey:@"main_window_foreground"];
        [loaderContainer addSubview:loaderText];
    }

    [self.window addSubview:loaderBG];
    [loaderBG addSubview:loaderContainer];
    
    loaderBG.alpha = 0.0f;
    loaderBG.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    
    [UIView animateWithDuration:0.2f animations:^{
        loaderBG.alpha = 1.0f;
        loaderBG.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    }];
}

- (void)hideLoader
{
    loaderBG.alpha = 1.0f;
    loaderBG.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
    
    [UIView animateWithDuration:0.2f animations:^{
        loaderBG.alpha = 0.0f;
        loaderBG.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
    } completion:^(BOOL finished) {
        [loaderBG removeFromSuperview];
        loaderBG = nil;
    }];
}


#pragma mark - Private methods

- (void)didLoadConfigurationFile
{
    UIColor * navBarColor = [[Config sharedInstance] colorForKey:@"main_window"];
    
    const double systemVersion = [[[UIDevice currentDevice] systemVersion] doubleValue];
    
    if (systemVersion >= 7.0)
    {
        [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                               NSForegroundColorAttributeName: [[Config sharedInstance] colorForKey:@"main_window_foreground"]
                                                               }];
        
        [[UINavigationBar appearance] setBarTintColor:navBarColor];
        
        resultContainerNavigationController.navigationBar.tintColor = [[Config sharedInstance] colorForKey:@"main_window_foreground"];
        helpContainerNavigationController.navigationBar.tintColor = [[Config sharedInstance] colorForKey:@"main_window_foreground"];
    }
    else
    {
        [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                               UITextAttributeTextColor: [[Config sharedInstance] colorForKey:@"main_window_foreground"],
                                                               UITextAttributeTextShadowColor: [UIColor colorWithWhite:0.0 alpha:0.4],
                                                               UITextAttributeTextShadowOffset: [NSValue valueWithCGSize:CGSizeMake(0.0, -0.5)]
                                                               }];
        
        resultContainerNavigationController.navigationBar.tintColor = navBarColor;
        helpContainerNavigationController.navigationBar.tintColor = navBarColor;
    }
}


#pragma mark - Custom alert view delegate

- (void)alertView:(ALCustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Closing an error message
    if (alertView.tag == 1000 && buttonIndex == 1)
    {
        if ([voteVerificationResultsViewController presentedModally])
        {
            [resultContainerNavigationController dismissModalViewControllerAnimated:YES];
        }

        [scannerViewController setScannerEnabled:YES];
    }
}

@end
