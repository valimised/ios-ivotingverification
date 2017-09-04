//
//  UIColor+UIColor_Hex.m
//  VVK

#import "UIColor+Hex.h"

@interface UIColor (Private)

+ (CGFloat)colorComponentFrom:(NSString *)string start:(NSUInteger)start length:(NSUInteger)length;

@end

@implementation UIColor (UIColor_Hex)

+ (UIColor *)colorWithHexString:(NSString *)hexString
{
    NSString * colorString = [[hexString stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    
    CGFloat alpha, red, blue, green;
    
    switch ([colorString length])
    {
        // #RGB
        case 3:
        {
            alpha = 1.0f;
            red = [self colorComponentFrom:colorString start:0 length:1];
            green = [self colorComponentFrom:colorString start:1 length:1];
            blue = [self colorComponentFrom:colorString start:2 length:1];
        }
        break;
        
        // #ARGB
        case 4:
        {
            alpha = [self colorComponentFrom:colorString start:0 length:1];
            red = [self colorComponentFrom:colorString start:1 length:1];
            green = [self colorComponentFrom:colorString start:2 length:1];
            blue = [self colorComponentFrom:colorString start:3 length:1];
        }
        break;
        
        // #RRGGBB
        case 6:
        {
            alpha = 1.0f;
            red = [self colorComponentFrom:colorString start:0 length:2];
            green = [self colorComponentFrom:colorString start:2 length:2];
            blue = [self colorComponentFrom:colorString start:4 length:2];
        }
        break;
        
        // #AARRGGBB
        case 8:
        {
            alpha = [self colorComponentFrom:colorString start:0 length:2];
            red = [self colorComponentFrom:colorString start:2 length:2];
            green = [self colorComponentFrom:colorString start:4 length:2];
            blue = [self colorComponentFrom:colorString start:6 length:2];
        }
        break;
            
        default:
        {
            alpha = 1.0f;
            red = 0.0f;
            green = 0.0f;
            blue = 0.0f;
        }
        break;
    }
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (CGFloat)colorComponentFrom:(NSString *)string start:(NSUInteger)start length:(NSUInteger)length
{
    unsigned hexComponent;
    NSString * substring = [string substringWithRange:NSMakeRange(start, length)];
    NSString * fullHex = length == 2 ? substring : [NSString stringWithFormat:@"%@%@", substring, substring];
    
    [[NSScanner scannerWithString:fullHex] scanHexInt:&hexComponent];
    
    return hexComponent / 255.0;
}

@end
