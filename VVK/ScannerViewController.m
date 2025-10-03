//
//  ScannerViewController.m
//  iVotingVerification

#import "ScannerViewController.h"
#import "VoteContainer.h"
#import "QRScanResult.h"
#import "RegexMatcher.h"
#import "AppDelegate.h"
#import "C.h"
#import "AccessibilityUtil.h"

@interface ScannerViewController (Private)

- (void) setupScanner;
- (void) startPreview;
- (void) stopPreview;
- (void) showWelcomeMessage;
- (void) shouldRestartApplicationState;
- (void) verifyQrString:(NSString*)qrStr;
- (void) setOrientationObserver;

@end

@implementation ScannerViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // Only portrait is supported because it locks and prevents the camera preview to rotate when device orientation changes
    return UIInterfaceOrientationMaskPortrait;
}

- (id) initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    session = nil;
#if !(TARGET_IPHONE_SIMULATOR)
    output = nil;
#endif
    readyToScan = FALSE;
    return self;
}

- (void) startPreview
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        if (![self->session isRunning]) {
            [self->session startRunning];
        }
    });
}

- (void) stopPreview
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        if ([self->session isRunning]) {
            [self->session stopRunning];
        }
    });
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startPreview];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopPreview];
}

- (void) dealloc {
    [self stopPreview];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    [self setupScanner];
    readyToScan = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              showWelcomeMessage) name:didLoadConfigurationFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              shouldRestartApplicationState) name:shouldRestartApplicationState object:nil];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - Private method implementations

- (void) setupScanner
{
#if !(TARGET_IPHONE_SIMULATOR)
    session = [[AVCaptureSession alloc] init];
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if (!session || !device) {
        [SharedDelegate presentError:[[Config sharedInstance] errorMessageForKey:@"bad_device_message"]];
        return;
    }

    NSError* error = nil;
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];

    if (!input) {
        NSLog(@"error: %@", error);
        [SharedDelegate presentError:[[Config sharedInstance] errorMessageForKey:@"bad_device_message"]];
        return;
    }

    [session addInput:input];

    AVCaptureVideoPreviewLayer* _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewLayer.bounds = self.view.bounds;
    _previewLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds),
                                         CGRectGetMidY(self.view.bounds));
    _previewLayer.frame = self.view.frame;
    [self.view.layer addSublayer:_previewLayer];
    [self startPreview];
#endif
}

- (void) showWelcomeMessage
{
    if ([SharedDelegate currentVoteContainer] || readyToScan ||
            [SharedDelegate error]) {
        return;
    }
    
    NSArray* appURL = [[Config sharedInstance] getParameter:@"verification_url"];
    ALCustomAlertView* alert;

    if (appURL == nil || [appURL count] == 0) {
        alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewMessage:[[Config sharedInstance] textForKey:@"welcome_message"],
                                           kAlertViewCancelButtonTitle:[[Config sharedInstance] textForKey:@"btn_more"],
                                           kAlertViewBackgroundColor:[[C sharedInstance] mainWindow],
                                           kAlertViewForegroundColor:[[C sharedInstance] mainWindowForeground]
                                                             }];
    }
    else {
        alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewMessage:[[Config sharedInstance] textForKey:@"welcome_message"],
                                           kAlertViewCancelButtonTitle:[[Config sharedInstance] textForKey:@"btn_more"],
                                           kAlertViewConfrimButtonTitle:[[Config sharedInstance] textForKey:@"btn_next"],
                                           kAlertViewBackgroundColor:[[C sharedInstance] mainWindow],
                                           kAlertViewForegroundColor:[[C sharedInstance] mainWindowForeground]
                                                             }];
    }

    [alert setDelegate:self];
    [alert show];
}

- (void) setScannerEnabled:(BOOL)enabled
{
    DLog(@"setScannerEnabled: %d", enabled);
#if !(TARGET_IPHONE_SIMULATOR)

    if (enabled == YES) {
        [[AccessibilityUtil sharedInstance] sendQRViewAnnouncment];

        if (!output) {
            output = [[AVCaptureMetadataOutput alloc] init];
        }
        if (!output) {
            NSString* err = [[Config sharedInstance] errorMessageForKey:@"bad_device_message"];
            [SharedDelegate presentError:err];
            return;
        }

        if (![session.outputs containsObject:output]) {
            [session addOutput:output];
            [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
            [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        }
    }
    else {
        [session removeOutput:output];
    }

#else
    NSString* qrStr =
        @"session-id-base64\nqr-code-base64\nvote-id-base64"; // paste the qr data represented with QR here
    [self verifyQrString:qrStr];
#endif
}

- (void) shouldRestartApplicationState
{
    readyToScan = NO;
    [SharedDelegate setCurrentVoteContainer:nil];
    [[Config sharedInstance] requestRemoteConfigurationFile];
}

- (void) verifyQrString:(NSString*)qrStr
{
    BOOL validScanResult = YES;
    NSArray* components = [qrStr componentsSeparatedByString:@"\n"];

    // Validate number of line components
    if (components.count != 3) {
        validScanResult = NO;
    }
    // Validate encoding
    else {
        for (NSUInteger i = 1; i < components.count; ++i) {
            if (![RegexMatcher isBase64Encoded:components[i]]) {
                validScanResult = NO;
                break;
            }
        }
    }

#if (TARGET_APPSTORE_SCREENSHOTS)
    validScanResult = YES;
#endif

    if (validScanResult == YES) {
        QRScanResult* scanResult = [[QRScanResult alloc] initWithSymbolData:qrStr];
        VoteContainer* voteContainer = [[VoteContainer alloc] initWithScanResult:scanResult];
        [SharedDelegate showLoaderWithClearStyle:NO];
        [SharedDelegate setCurrentVoteContainer:voteContainer];
        [voteContainer download];
    }
    else {
        [SharedDelegate presentError:[[Config sharedInstance] errorMessageForKey:
                                      @"problem_qrcode_message"]];
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void) captureOutput:(AVCaptureOutput*)captureOutput
    didOutputMetadataObjects:(NSArray*)metadataObjects
    fromConnection:(AVCaptureConnection*)connection
{
    for (AVMetadataObject * metadata in metadataObjects) {
        if (![metadata.type isEqualToString:AVMetadataObjectTypeQRCode]) {
            continue;
        }

        [self setScannerEnabled:NO];
        NSString* scanResultString = [(AVMetadataMachineReadableCodeObject*)metadata stringValue];
        [self verifyQrString:scanResultString];
        break;
    }
}


#pragma mark - Custom alert view delegate

- (void) alertView:(ALCustomAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        [SharedDelegate presentHelpScreen];
    }
    else if (buttonIndex == 1) {
        readyToScan = YES;
        [self setScannerEnabled:YES];
    }
}

@end
