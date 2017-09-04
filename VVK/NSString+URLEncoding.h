//
//  NSString+URLEncoding.h
//  VVK

#import <Foundation/Foundation.h>

@interface NSString (URLEncoding)

+ (NSString *)URLEncodedStringWithDictionary:(NSDictionary *)dictionary;

@end
