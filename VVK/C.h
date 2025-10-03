//
//  C.h
//  VVK
//
//  Created by Kasutaja on 23.04.2024.
//

#define TAG_VOTE_SIGNER_WINDOW 1001

@interface C : NSObject

+ (C*) sharedInstance;

#pragma mark - Colors
- (UIColor*) errorWindow;
- (UIColor*) errorWindowForeground;
- (UIColor*) mainWindowForeground;
- (UIColor*) mainWindow;
- (UIColor*) lblBackground;
- (UIColor*) lblForeground;
- (UIColor*) lblOuterContainerBackground;
- (UIColor*) lblOuterContainerForeground;
- (UIColor*) lblInnerContainerForeground;
- (UIColor*) lblCloseTimeoutForeground;
- (UIColor*) lblCloseTimeoutBackgroundCenter;
- (UIColor*) lblOuterInnerContainerDivider;

@end
