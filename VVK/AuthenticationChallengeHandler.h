//
//  AuthenticationChallengeHandler.h
//  VVK

#import <Foundation/Foundation.h>

#import "Request.h"

#define CA_CERTIFICATE_FILE1 @"/eh.valimised.ee.der.cer"

@interface AuthenticationChallengeHandler : NSObject <RequestDelegate>

+ (AuthenticationChallengeHandler *)sharedInstance;

@end
