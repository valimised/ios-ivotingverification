//
//  DoRotation.m
//  VVK
//
//  Created by Kasutaja on 16.10.2024.
//

#import "DoRotation.h"

@implementation DoRotation

+ (DoRotation*) sharedInstance
{
    static DoRotation* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        sharedInstance = [[DoRotation alloc] init];
    });
    return sharedInstance;
}

- (BOOL) isValidOrientation:(UIDeviceOrientation)orientation
{
    return orientation == UIDeviceOrientationPortrait ||
           orientation == UIDeviceOrientationLandscapeLeft ||
           orientation == UIDeviceOrientationLandscapeRight;
}

- (void) changeFrameForOrientation:(UIDeviceOrientation)orientation forView:(UIView*)view
{
    if ([self isValidOrientation:orientation]) {
        float rotationAngle = 0.f;
        switch (orientation) {
            case UIDeviceOrientationLandscapeLeft:
                rotationAngle = M_PI_2;
                break;
            case UIDeviceOrientationLandscapeRight:
                rotationAngle = -M_PI_2;
                break;
            default:
                rotationAngle = 0.f;
                break;
        }
        view.transform = CGAffineTransformRotate(CGAffineTransformIdentity, rotationAngle);
    }
}

- (void) rotateViewIfNeeded:(UIView*)view
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    [self changeFrameForOrientation:orientation forView:view];
}

@end
