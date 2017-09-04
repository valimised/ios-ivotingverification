//
//  RegexMatcher.h
//  VVK

#import <Foundation/Foundation.h>

@interface RegexMatcher : NSObject

+ (BOOL)isSingleOrDoubleDigit:(NSString *)integer;
+ (BOOL)isSingleDigit:(NSString *)integer;
+ (BOOL)is40Characters:(NSString *)input;
+ (BOOL)isBase64Encoded:(NSString *)input;

@end
