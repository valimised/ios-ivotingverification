//
//  AccessibilityUtil.m
//  VVK
//
//  Created by Kasutaja on 11.11.2024.
//

#import "AccessibilityUtil.h"

@implementation AccessibilityUtil

+ (AccessibilityUtil*) sharedInstance
{
    static AccessibilityUtil* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        sharedInstance = [[AccessibilityUtil alloc] init];
    });
    return sharedInstance;
}

- (void) setDefaultAccesibilityFocusOnView:(UIView *)view
{
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, view);
}

- (void) sendQRViewAnnouncment
{
    NSString* announcement = [[Config sharedInstance] textForKey:@"a11y_qr_view_opened"];
    
    // Use a delay so the new view can initialize fully before the announcement is triggered
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, announcement);
    });
}

- (void) informAboutTimeLimit:(NSString*)time
{
    NSString* message = [[Config sharedInstance] textForKey:@"lbl_close_timeout"];
    message = [message stringByReplacingOccurrencesOfString:@"XX" withString:time];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

@end
