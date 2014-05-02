//
//  AuthenticationChallengeHandler.h
//  VVK
//
//  Created by Eigen Lenk on 2/12/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Request.h"

#define CA_CERTIFICATE_FILE1 @"/ca.cer"
#define CA_CERTIFICATE_FILE2 @"/Juur-SK.der.crt"

@interface AuthenticationChallengeHandler : NSObject <RequestDelegate>

+ (AuthenticationChallengeHandler *)sharedInstance;

@end
