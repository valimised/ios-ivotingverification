//
//  NSString+URLEncoding.h
//  VVK
//
//  Created by Eigen Lenk on 1/30/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (URLEncoding)

+ (NSString *)URLEncodedStringWithDictionary:(NSDictionary *)dictionary;

@end
