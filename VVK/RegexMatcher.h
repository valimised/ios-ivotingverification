//
//  RegexMatcher.h
//  VVK
//
//  Created by Eigen Lenk on 1/31/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RegexMatcher : NSObject

+ (BOOL)isSingleOrDoubleDigit:(NSString *)integer;
+ (BOOL)isSingleDigit:(NSString *)integer;
+ (BOOL)is40Characters:(NSString *)input;

@end
