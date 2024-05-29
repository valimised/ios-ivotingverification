//
//  AuthenticationChallengeHandler.h
//  VVK

#import <Foundation/Foundation.h>

#import "Request.h"

@interface AuthenticationChallengeHandler : NSObject <RequestDelegate>

+ (AuthenticationChallengeHandler*) sharedInstance;

@end
