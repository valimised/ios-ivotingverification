//
//  JsonRpc.h
//  VVK

#import <Foundation/Foundation.h>

@interface JsonRpc : NSObject

+ (NSString*) METHOD_VERIFY;

+ (NSData*) createRequest:(NSString*)method withParams:(NSDictionary*)params;
+ (NSDictionary*) unmarshalResponse:(NSData*)inStream;


@end
