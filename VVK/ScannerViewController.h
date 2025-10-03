//
//  ScannerViewController.h
//  iVotingVerification

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "ALCustomAlertView.h"

@interface ScannerViewController : UIViewController
    <ALCustomAlertViewDelegate, AVCaptureMetadataOutputObjectsDelegate>
{
@private

    AVCaptureSession* session;
#if !(TARGET_IPHONE_SIMULATOR)
    AVCaptureMetadataOutput* output;
#endif
    BOOL readyToScan;
}

@end
