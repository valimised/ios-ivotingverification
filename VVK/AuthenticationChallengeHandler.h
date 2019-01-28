//
//  AuthenticationChallengeHandler.h
//  VVK

#import <Foundation/Foundation.h>

#import "Request.h"

#define CA_CERTIFICATE_FILE1 @"/conf_server_certificate.der.crt"

@interface AuthenticationChallengeHandler : NSObject <RequestDelegate>

+ (AuthenticationChallengeHandler *)sharedInstance;

@end
