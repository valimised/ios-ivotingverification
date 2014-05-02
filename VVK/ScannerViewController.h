//
//  ScannerViewController.h
//  iVotingVerification
//
//  Created by Eigen Lenk on 1/28/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "ALCustomAlertView.h"
#import "ZBarReaderView.h"

@interface ScannerViewController : UIViewController <ZBarReaderViewDelegate, ALCustomAlertViewDelegate>
{
    @private
    ZBarReaderView * zBarReaderView;
    AVCaptureDevice * captureDevice;
    UIView * reticleView;
    BOOL readyToScan;
    BOOL welcomeMessagePresented;
}

- (void)setScannerEnabled:(BOOL)enabled;

@end
