//
//  ScaledFonts.m
//  VVK
//
//  Created by Kasutaja on 15.11.2024.
//

#import "ScaledFonts.h"

@implementation ScaledFonts

CGFloat MAX_MULTIPLIER = 2.0;

+ (ScaledFonts*) sharedInstance
{
    static ScaledFonts* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        sharedInstance = [[ScaledFonts alloc] init];
    });
    return sharedInstance;
}

- (void) applyScaledFontToSubviewsOfView:(UIView *)view
{
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            UIFont *baseFont = label.font;
            CGFloat maxFontSize = label.font.pointSize * MAX_MULTIPLIER;
            UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
            UIFont* customScaledFont = [metrics scaledFontForFont:baseFont maximumPointSize:maxFontSize];
            label.font = customScaledFont;
            label.adjustsFontForContentSizeCategory = YES;
        } else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            UIFont *baseFont = button.titleLabel.font;
            CGFloat maxFontSize = button.titleLabel.font.pointSize * MAX_MULTIPLIER;
            UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
            UIFont* customScaledFont = [metrics scaledFontForFont:baseFont maximumPointSize:maxFontSize];
            button.titleLabel.font = customScaledFont;
            button.titleLabel.adjustsFontForContentSizeCategory = YES;
        }
    }
}

- (void) applyScaledFontToUILabel:(UILabel *)label
{
    UIFont *baseFont = label.font;
    CGFloat maxFontSize = label.font.pointSize * MAX_MULTIPLIER;
    UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
    UIFont* customScaledFont = [metrics scaledFontForFont:baseFont maximumPointSize:maxFontSize];
    label.font = customScaledFont;
    label.adjustsFontForContentSizeCategory = YES;
}

@end
