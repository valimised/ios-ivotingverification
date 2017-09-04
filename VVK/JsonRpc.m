//
//  JsonRpc.m
//  VVK

#import "JsonRpc.h"

@implementation JsonRpc

+ (NSString *)METHOD_VERIFY { return @"RPC.Verify"; }

+ (NSData *)createRequest:(NSString *)method withParams:(NSDictionary *)params {
    NSArray* paramsArray = @[params];
    NSDictionary* jsonDict = @{
                               @"method": method,
                               @"params": paramsArray,
                               @"id": @"1"
                               };
    DLog("%@", jsonDict);
    return [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
}

+ (NSDictionary *)unmarshalResponse:(NSData *)jsonData {
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}


@end
