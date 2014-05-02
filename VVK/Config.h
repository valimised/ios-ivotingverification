//
//  Config.h
//  iVotingVerification
//
//  Created by Eigen Lenk on 1/28/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Request.h"
#import "ALCustomAlertView.h"

// Configuration keys
static NSString * kConfigRootKey = @"appConfig";
static NSString * kConfigColorsKey = @"colors";
static NSString * kConfigErrorsKey = @"errors";
static NSString * kConfigTextsKey = @"texts";
static NSString * kConfigParamsKey = @"params";
static NSString * kPublicKeyKey = @"public_key";

// Notification keys
static NSString * didLoadConfigurationFile = @"VVK_didLoadConfigurationFile";
static NSString * shouldRestartApplicationState = @"VVK_shouldRestartApplicationState";


@interface Config : NSObject <RequestDelegate, ALCustomAlertViewDelegate>
{
    __strong NSDictionary * config;
    
    @private
    BOOL isLoaded;
    BOOL isRequesting;
}

@property (nonatomic, readonly) BOOL isLoaded;

+ (Config *)sharedInstance;

- (void)requestRemoteConfigurationFile;

- (UIColor *)colorForKey:(NSString *)key;
- (NSString *)errorMessageForKey:(NSString *)key;
- (NSString *)textForKey:(NSString *)key;
- (id)getParameter:(NSString *)key;
- (NSString *)publicKey;

@end
