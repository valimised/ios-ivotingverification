//
//  DoRotation.h
//  VVK
//
//  Created by Kasutaja on 16.10.2024.
//

#import <Foundation/Foundation.h>

@interface DoRotation : NSObject

+ (DoRotation*) sharedInstance;

- (void) changeFrameForOrientation:(UIDeviceOrientation)orientation forView:(UIView*)view;
- (void) rotateViewIfNeeded:(UIView*)view;

@end
