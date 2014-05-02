//
//  ScannerViewController.m
//  iVotingVerification
//
//  Created by Eigen Lenk on 1/28/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "ScannerViewController.h"
#import "VoteContainer.h"
#import "QRScanResult.h"
#import "AppDelegate.h"

@interface ScannerViewController (Private)

- (void)setupScanner;
- (void)showWelcomeMessage;
- (void)shouldRestartApplicationState;
- (void)setReticleVisible:(BOOL)visible;

@end

@implementation ScannerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {

    }
    
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 7.0) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    }
    
    [zBarReaderView start];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (readyToScan == NO && [[Config sharedInstance] isLoaded] && welcomeMessagePresented == NO)
    {
        [self showWelcomeMessage];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 7.0) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    }
    
    [zBarReaderView stop];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupScanner];
    
    readyToScan = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showWelcomeMessage) name:didLoadConfigurationFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldRestartApplicationState) name:shouldRestartApplicationState object:nil];
    
    const float reticleSize = 175.0f;
    CGRect screenBounds = [[UIScreen screens][0] bounds];
    CGRect rect = CGRectMake((screenBounds.size.width - reticleSize) * 0.5f, (screenBounds.size.height - reticleSize) * 0.5f, reticleSize, reticleSize);
    
    reticleView = [[UIView alloc] initWithFrame:rect];
    
    reticleView.backgroundColor = [UIColor clearColor];
    reticleView.layer.borderColor = [UIColor whiteColor].CGColor;
    reticleView.layer.borderWidth = 1.0f;
    reticleView.layer.cornerRadius = 16.f;
    reticleView.alpha = 0.0f;
    
    [self.view addSubview:reticleView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - Private method implementations

- (void)setupScanner
{
#if !(TARGET_IPHONE_SIMULATOR)
    
    captureDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][0];
    
    ZBarImageScanner * scanner = [ZBarImageScanner new];
    
    // We're only interested in QR code scanning with full ASCII set
    [scanner setSymbology:ZBAR_NONE config:ZBAR_CFG_ENABLE to:0];
    [scanner setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ENABLE to:1];
    [scanner setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ASCII to:1];
    
    zBarReaderView = [[ZBarReaderView alloc] initWithImageScanner:scanner];
    
    zBarReaderView.device = captureDevice;
    zBarReaderView.zoom = 1.15f;
    zBarReaderView.tracksSymbols = NO;
    zBarReaderView.allowsPinchZoom = NO;
    zBarReaderView.frame = self.view.bounds;
    zBarReaderView.torchMode = 0;
    zBarReaderView.readerDelegate = self;
    zBarReaderView.scanCrop = CGRectZero;
   
    [zBarReaderView start];
    
    [[self view] addSubview:zBarReaderView];
    
#else
    
    captureDevice = nil;
    
    ZBarImageScanner * scanner = [ZBarImageScanner new];
    
    zBarReaderView = [[ZBarReaderView alloc] initWithImageScanner:scanner];

    zBarReaderView.zoom = 1.15f;
    zBarReaderView.tracksSymbols = NO;
    zBarReaderView.allowsPinchZoom = NO;
    zBarReaderView.frame = self.view.bounds;
    zBarReaderView.torchMode = 0;
    zBarReaderView.readerDelegate = self;
    zBarReaderView.scanCrop = CGRectZero;
    
    [zBarReaderView start];
    
    [[self view] addSubview:zBarReaderView];
    
#endif
    
}

- (void)showWelcomeMessage
{
    if ([SharedDelegate currentVoteContainer] || welcomeMessagePresented || readyToScan) {
        return;
    }
    
    welcomeMessagePresented = YES;
    
    NSString * appURL = [[Config sharedInstance] getParameter:@"app_url"];
    
    ALCustomAlertView * alert;
    
    if (appURL == nil || [appURL length] == 0)
    {
        alert = [[ALCustomAlertView alloc] initWithOptions:@{kAlertViewMessage: [[Config sharedInstance] textForKey:@"welcome_message"],
                                                             kAlertViewCancelButtonTitle: [[Config sharedInstance] textForKey:@"btn_more"],
                                                             kAlertViewBackgroundColor: [[Config sharedInstance] colorForKey:@"main_window"],
                                                             kAlertViewForegroundColor: [[Config sharedInstance] colorForKey:@"main_window_foreground"]}];
    }
    else
    {
        alert = [[ALCustomAlertView alloc] initWithOptions:@{kAlertViewMessage: [[Config sharedInstance] textForKey:@"welcome_message"],
                                                             kAlertViewCancelButtonTitle: [[Config sharedInstance] textForKey:@"btn_more"],
                                                             kAlertViewConfrimButtonTitle: [[Config sharedInstance] textForKey:@"btn_next"],
                                                             kAlertViewBackgroundColor: [[Config sharedInstance] colorForKey:@"main_window"],
                                                             kAlertViewForegroundColor: [[Config sharedInstance] colorForKey:@"main_window_foreground"]}];
    }
    
    [alert setDelegate:self];
    [alert show];
}

- (void)setScannerEnabled:(BOOL)enabled
{
    DLog(@"setScannerEnabled: %d", enabled);
    
    if (enabled == YES)
    {
        [self setReticleVisible:YES];
        
        zBarReaderView.scanCrop = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    
#if TARGET_IPHONE_SIMULATOR
        if ([zBarReaderView respondsToSelector:@selector(scanImage:)]) {
            [zBarReaderView performSelector:@selector(scanImage:) withObject:[UIImage imageNamed:@"scantest.png"]];
        }
#endif
    }
    else
    {
        zBarReaderView.scanCrop = CGRectZero;
    }
    
    return;
}

- (void)shouldRestartApplicationState
{
    readyToScan = NO;
    
    reticleView.hidden = YES;
    reticleView.alpha = 0.0f;
    
    [SharedDelegate setCurrentVoteContainer:nil];
    
    [[Config sharedInstance] requestRemoteConfigurationFile];
}

- (void)setReticleVisible:(BOOL)visible
{
    if (visible == YES)
    {
        reticleView.hidden = NO;
        reticleView.alpha = 0.0f;
        
        [UIView animateWithDuration:0.4 animations:^{
            reticleView.alpha = 1.0f;
        } completion:^(BOOL finished) {
        }];
    }
    else
    {
        reticleView.hidden = NO;
        reticleView.alpha = 1.0f;
        
        [UIView animateWithDuration:0.4 animations:^{
            reticleView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            reticleView.hidden = YES;
        }];
    }
}

#pragma mark - ZBar delegate

- (void)readerView:(ZBarReaderView *)view
    didReadSymbols:(ZBarSymbolSet *)symbols
         fromImage:(UIImage *)image
{
    for (ZBarSymbol * sym in symbols)
    {
        [self setReticleVisible:NO];
        
        QRScanResult * scanResult = [[QRScanResult alloc] initWithSymbolData:sym.data];
        
        VoteContainer * voteContainer = [[VoteContainer alloc] initWithScanResult:scanResult];

        [self setScannerEnabled:NO];
        
        [SharedDelegate showLoaderWithClearStyle:NO];
        
        [SharedDelegate setCurrentVoteContainer:voteContainer];
    
        [voteContainer download];
        
        break;
    }
}


#pragma mark - Custom alert view delegate

- (void)alertView:(ALCustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    welcomeMessagePresented = NO;
    
    if (buttonIndex == 0)
    {
        [SharedDelegate presentHelpScreen];
    }
    else if (buttonIndex == 1)
    {
        readyToScan = YES;
        
        [self setScannerEnabled:YES];
    }
}

@end
