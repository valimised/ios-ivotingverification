//
//  RegexMatcher.m
//  VVK
//
//  Created by Eigen Lenk on 1/31/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

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

@end
