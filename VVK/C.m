//
//  C.m
//  VVK
//
//  Created by Kasutaja on 23.04.2024.
//

#import "C.h"
#import "UIColor+Hex.h"

@implementation C

+ (C*) sharedInstance
{
    static C* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        sharedInstance = [[C alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Colors

- (UIColor *)errorWindow {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"error_window"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#FF0000"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)errorWindowForeground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"error_window_foreground"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#FFFFFF"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)mainWindowForeground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"main_window_foreground"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#FFFFFF"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)mainWindow {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"main_window"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#33B5E5"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblBackground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_background"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#33B5E5"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblForeground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_foreground"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#FFFFFF"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblOuterContainerBackground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_outer_container_background"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#EAEAEA"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblOuterContainerForeground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_outer_container_foreground"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#404040"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblInnerContainerForeground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_inner_container_foreground"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#404040"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblCloseTimeoutForeground {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_close_timeout_foreground"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#454444"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblCloseTimeoutBackgroundCenter {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_close_timeout_background_center"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#F9D303"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

- (UIColor *)lblOuterInnerContainerDivider {
    UIColor* configColor = [[Config sharedInstance] colorForKey:@"lbl_outer_inner_container_divider"];
    UIColor* defaultColor = [UIColor colorWithHexString:@"#595959"];
    return configColor != UIColor.clearColor ? configColor : defaultColor;
}

@end
