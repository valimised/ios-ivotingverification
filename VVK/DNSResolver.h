//
//  DNSResolver.h

#import <Foundation/Foundation.h>

@interface DNSResolver : NSObject
@property NSString *hostname;
@property NSArray *addresses;
@property NSError *error;
-(BOOL)lookup;
@end
