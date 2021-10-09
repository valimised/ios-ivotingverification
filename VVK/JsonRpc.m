//
//  JsonRpc.m
//  VVK

#import "JsonRpc.h"
#import <sys/utsname.h>

@interface JsonRpc()
+ (NSString*) getPhoneInfo;
@end

@implementation JsonRpc

+ (NSString*) METHOD_VERIFY
{
    return @"RPC.Verify";
}

+ (NSData*) createRequest:(NSString*)method withParams:(NSDictionary*)params
{
    NSMutableDictionary* paramsCopy = [params mutableCopy];
    paramsCopy[@"os"] = [self getPhoneInfo];
    NSArray* paramsArray = @[paramsCopy];
    NSDictionary* jsonDict = @ {
@"method":
        method,
@"params":
        paramsArray,
@"id":
        @"1"
    };
    DLog("%@", jsonDict);
    return [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
}

+ (NSDictionary*) unmarshalResponse:(NSData*)jsonData
{
#ifdef DEBUG
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    DLog(@"%@", jsonString);
#endif
    NSError* error = nil;
    NSDictionary* ret = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    DLog(@"%@, %@", ret, error);
    return ret;
}

+ (NSString*) getPhoneInfo
{
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* model = [[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding]
                       stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    NSString* res = [NSString stringWithFormat:@"iOS %ld.%ld.%ld %@",
                              (long)os.majorVersion, (long)os.minorVersion, (long)os.patchVersion, model];
    return [res length] > 100 ? [res substringWithRange:NSMakeRange(0, 100)] : res;
}

@end
