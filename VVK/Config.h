//
//  Config.h
//  iVotingVerification

#import <Foundation/Foundation.h>

#import "Request.h"
#import "ALCustomAlertView.h"

// Configuration keys
static NSString* kConfigRootKey = @"appConfig";
static NSString* kConfigColorsKey = @"colors";
static NSString* kConfigErrorsKey = @"errors";
static NSString* kConfigTextsKey = @"texts";
static NSString* kConfigParamsKey = @"params";
static NSString* kConfigVersionsKey = @"versions";
static NSString* kConfigElectionsKey = @"elections";
static NSString* kPublicKeyKey = @"public_key";
static NSString* kConfigIOSVersion = @"ios_bundle_version";

// Notification keys
static NSString* didLoadConfigurationFile = @"VVK_didLoadConfigurationFile";
static NSString* shouldRestartApplicationState = @"VVK_shouldRestartApplicationState";


@interface Config : NSObject <RequestDelegate, ALCustomAlertViewDelegate>
{
    __strong NSDictionary* config;
@private
    BOOL isLoaded;
    BOOL isRequesting;
}

@property (nonatomic, readonly) BOOL isLoaded;

+ (Config*) sharedInstance;

- (BOOL) needsUpdate:(NSString*)configVersion;
- (void) requestRemoteConfigurationFile;

- (UIColor*) colorForKey:(NSString*)key;
- (NSString*) errorMessageForKey:(NSString*)key;
- (NSString*) textForKey:(NSString*)key;
- (id) getParameter:(NSString*)key;
- (NSString*) publicKey;
- (NSString*) electionForKey:(NSString*)key;

@end
