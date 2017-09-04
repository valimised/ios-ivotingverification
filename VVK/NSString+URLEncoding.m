//
//  NSString+URLEncoding.m
//  VVK

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
            NSString * value = dictionary[key]; // (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)dictionary[key], NULL, CFSTR("+=&"), kCFStringEncodingUTF8));
            
            if (ch)
            {
                [outString appendFormat:@"%c", ch];
            }
            
            [outString appendFormat:@"%@=%@", key, value];
            
            ch = '&'; // (ch == '=') ? '&' : '=';
        }
	}
    
    DLog(@"outString: %@", outString);
    DLog(@"percent escaped outString: %@", [outString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);
	
	return [outString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}


@end
