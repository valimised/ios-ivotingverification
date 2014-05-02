//
//  NSString+URLEncoding.m
//  VVK
//
//  Created by Eigen Lenk on 1/30/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "NSString+URLEncoding.h"

@implementation NSString (URLEncoding)

+ (NSString *)URLEncodedStringWithDictionary:(NSDictionary *)dictionary
{
	NSMutableString * outString = [NSMutableString string];

	char ch = 0x0;
	
	for (NSString * key in dictionary)
    {
		if ([key isKindOfClass:[NSString class]])
        {
            NSString * value = (NSString*)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)dictionary[key], NULL, CFSTR("+=&"), kCFStringEncodingUTF8));
            
            if (ch)
                [outString appendFormat:@"%c", ch];
            
            [outString appendFormat:@"%@=%@", key, value];
            
            ch = (ch == '=') ? '&' : '=';
        }
	}
	
	return [outString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}


@end
