//
//  RegexMatcher.m
//  VVK

#import "RegexMatcher.h"

@implementation RegexMatcher

+ (BOOL)isSingleOrDoubleDigit:(NSString *)integer
{
    NSError * regexError = nil;
    NSRegularExpression * expression = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,2}$" options:0 error:&regexError];
    NSString * input = [NSString stringWithFormat:@"%@", integer];
    NSRange inputRange = NSMakeRange(0, input.length);
    
    NSTextCheckingResult * match = [expression firstMatchInString:input options:0 range:inputRange];
    
    DLog(@"match = %@", match);
    
    return (match != nil);
}

+ (BOOL)isSingleDigit:(NSString *)integer
{
    NSError * regexError = nil;
    NSRegularExpression * expression = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1}$" options:0 error:&regexError];
    NSString * input = [NSString stringWithFormat:@"%@", integer];
    NSRange inputRange = NSMakeRange(0, input.length);
    
    NSTextCheckingResult * match = [expression firstMatchInString:input options:0 range:inputRange];
    
    DLog(@"match = %@", match);
    
    return (match != nil);
}

+ (BOOL)is40Characters:(NSString *)input
{
    DLog(@"%@", input);
    
    NSError * regexError = nil;
    NSRegularExpression * expression = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-Za-z]{40}$" options:0 error:&regexError];
    NSRange inputRange = NSMakeRange(0, input.length);
    
    NSTextCheckingResult * match = [expression firstMatchInString:input options:0 range:inputRange];
    
    DLog(@"match = %@", match);
    
    return (match != nil);
}

+ (BOOL)isBase64Encoded:(NSString *)input
{
    NSError * regexError = nil;
    NSRegularExpression * expression = [NSRegularExpression regularExpressionWithPattern:
                                        @"^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{4}|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)$"
                                        options:0 error:&regexError];
    NSRange inputRange = NSMakeRange(0, input.length);
    
    NSTextCheckingResult * match = [expression firstMatchInString:input options:0 range:inputRange];
    
    DLog(@"match = %@", match);
    
    return (match != nil);
}

@end
