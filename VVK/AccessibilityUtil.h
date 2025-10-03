//
//  AccessibilityUtil.h
//  VVK
//
//  Created by Kasutaja on 11.11.2024.
//

#import <Foundation/Foundation.h>

@interface AccessibilityUtil : NSObject

+ (AccessibilityUtil*) sharedInstance;

#pragma mark - Public methods

- (void) setDefaultAccesibilityFocusOnView:(UIView*)view;
- (void) sendQRViewAnnouncment;
- (void) informAboutTimeLimit:(NSString*)time;

@end
