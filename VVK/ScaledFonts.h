//
//  ScaledFonts.h
//  VVK
//
//  Created by Kasutaja on 15.11.2024.
//

#import <Foundation/Foundation.h>

@interface ScaledFonts : NSObject

+ (ScaledFonts*) sharedInstance;

#pragma mark - Public methods

- (void) applyScaledFontToSubviewsOfView:(UIView*)view;
- (void) applyScaledFontToUILabel:(UILabel*)label;

@end
