//
//  ScannerViewController.m
//  iVotingVerification

#import "ScannerViewController.h"
#import "VoteContainer.h"
#import "QRScanResult.h"
#import "RegexMatcher.h"
#import "AppDelegate.h"

@interface ScannerViewController (Private)

- (void) setupScanner;
- (void) showWelcomeMessage;
- (void) shouldRestartApplicationState;
- (void) setReticleVisible:(BOOL)visible;
- (void) verifyQrString:(NSString*)qrStr;

@end

@implementation ScannerViewController

- (id) initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
    }

    return self;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setupScanner];
    [session startRunning];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (readyToScan == NO && [[Config sharedInstance] isLoaded] && welcomeMessagePresented == NO) {
        [self showWelcomeMessage];
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [session stopRunning];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    readyToScan = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              showWelcomeMessage) name:didLoadConfigurationFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
                                              shouldRestartApplicationState) name:shouldRestartApplicationState object:nil];
    const float reticleSize = 175.0f;
    CGRect screenBounds = [[UIScreen screens][0] bounds];
    CGRect rect = CGRectMake((screenBounds.size.width - reticleSize) * 0.5f,
                             (screenBounds.size.height - reticleSize) * 0.5f, reticleSize, reticleSize);
    reticleView = [[UIView alloc] initWithFrame:rect];
    reticleView.backgroundColor = [UIColor clearColor];
    reticleView.layer.borderColor = [UIColor whiteColor].CGColor;
    reticleView.layer.borderWidth = 1.0f;
    reticleView.layer.cornerRadius = 16.f;
    reticleView.alpha = 0.0f;
    [self.view addSubview:reticleView];
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
    NSError* error = nil;
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];

    if (input) {
        // Add the input to the session
        [session addInput:input];
    }
    else {
        NSLog(@"error: %@", error);
        NSString* err = [[Config sharedInstance] errorMessageForKey:@"bad_device_message"];

        if (!err) {
            err = @"Kaamera kasutamine ebaõnnestus. Palun taaskäivitage rakendus.";
        }

        [SharedDelegate presentDefaultError:err];
        return;
    }

    AVCaptureVideoPreviewLayer* _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewLayer.bounds = self.view.bounds;
    _previewLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds),
                                         CGRectGetMidY(self.view.bounds));
    [self.view.layer addSublayer:_previewLayer];
    [session startRunning];
#endif
}

- (void) showWelcomeMessage
{
    if ([SharedDelegate currentVoteContainer] || welcomeMessagePresented || readyToScan ||
            [SharedDelegate error]) {
        return;
    }

    welcomeMessagePresented = YES;
    NSArray* appURL = [[Config sharedInstance] getParameter:@"verification_url"];
    ALCustomAlertView* alert;

    if (appURL == nil || [appURL count] == 0) {
        alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewMessage:[[Config sharedInstance] textForKey:@"welcome_message"],
                                           kAlertViewCancelButtonTitle:[[Config sharedInstance] textForKey:@"btn_more"],
                                           kAlertViewBackgroundColor:[[Config sharedInstance] colorForKey:@"main_window"],
                                           kAlertViewForegroundColor:[[Config sharedInstance] colorForKey:@"main_window_foreground"]
                                                             }];
    }
    else {
        alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewMessage:[[Config sharedInstance] textForKey:@"welcome_message"],
                                           kAlertViewCancelButtonTitle:[[Config sharedInstance] textForKey:@"btn_more"],
                                           kAlertViewConfrimButtonTitle:[[Config sharedInstance] textForKey:@"btn_next"],
                                           kAlertViewBackgroundColor:[[Config sharedInstance] colorForKey:@"main_window"],
                                           kAlertViewForegroundColor:[[Config sharedInstance] colorForKey:@"main_window_foreground"]
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
        [self setReticleVisible:YES];
        output = [[AVCaptureMetadataOutput alloc] init];

        if (!output) {
            NSString* err = [[Config sharedInstance] errorMessageForKey:@"bad_device_message"];
            [SharedDelegate presentError:err];
            return;
        }

        [session addOutput:output];
        [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
        [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    }
    else {
        [self setReticleVisible:NO];
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
    reticleView.hidden = YES;
    reticleView.alpha = 0.0f;
    [SharedDelegate setCurrentVoteContainer:nil];
    [[Config sharedInstance] requestRemoteConfigurationFile];
}

- (void) setReticleVisible:(BOOL)visible
{
    if (visible == YES) {
        reticleView.hidden = NO;
        reticleView.alpha = 0.0f;
        [UIView animateWithDuration:0.4 animations:^ {
                   self->reticleView.alpha = 1.0f;
               } completion: ^ (BOOL finished) {
        }];
    }
    else {
        reticleView.hidden = NO;
        reticleView.alpha = 1.0f;
        [UIView animateWithDuration:0.4 animations:^ {
                   self->reticleView.alpha = 0.0f;
               } completion: ^ (BOOL finished) {
            self->reticleView.hidden = YES;
        }];
    }
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
    welcomeMessagePresented = NO;

    if (buttonIndex == 0) {
        [SharedDelegate presentHelpScreen];
    }
    else if (buttonIndex == 1) {
        readyToScan = YES;
        [self setScannerEnabled:YES];
    }
}

@end
