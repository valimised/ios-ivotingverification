//
//  Config.m
//  iVotingVerification

#import "Config.h"
#import "Request.h"
#import "UIColor+Hex.h"
#import "AppDelegate.h"
#import "AuthenticationChallengeHandler.h"


@implementation Config

@synthesize isLoaded;

+ (Config*) sharedInstance
{
    static Config* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        sharedInstance = [[Config alloc] init];
    });
    return sharedInstance;
}

- (id) init
{
    self = [super init];

    if (self) {
        isLoaded = NO;
    }

    return self;
}

#pragma mark - Public methods

- (void) requestRemoteConfigurationFile
{
    if (isRequesting) {
        return;
    }

    __weak NSString* bundleConfigPath = [[NSBundle mainBundle] pathForResource:@"config" ofType:@"txt"];
    NSString* bundleConfigContents =   [[NSString stringWithContentsOfFile:bundleConfigPath encoding:
                                         NSUTF8StringEncoding error:nil] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    NSURL* configURL = [NSURL URLWithString:bundleConfigContents];
    Request* request = [[Request alloc] initWithURL:configURL];
    request.delegate = self;
    request.authenticationDelegate = [AuthenticationChallengeHandler sharedInstance];
    request.validHost = configURL.host;
    [SharedDelegate showLoaderWithClearStyle:YES];
    isRequesting = YES;
    [request start];
    return;
}

- (NSString*) errorMessageForKey:(NSString*)key
{
    return config[kConfigRootKey][kConfigErrorsKey][key];
}

- (NSString*) textForKey:(NSString*)key
{
    NSString* result = config[kConfigRootKey][kConfigTextsKey][key];

    if (!result) {
        result = key;
    }

    return result;
}

- (UIColor*) colorForKey:(NSString*)key
{
    return [UIColor colorWithHexString:config[kConfigRootKey][kConfigColorsKey][key]];
}

- (id) getParameter:(NSString*)key
{
    return config[kConfigRootKey][kConfigParamsKey][key];
}

- (NSString*) publicKey
{
    return config[kConfigRootKey][kConfigParamsKey][kPublicKeyKey];
}

- (NSString*) electionForKey:(NSString*)key
{
    return config[kConfigRootKey][kConfigElectionsKey][key];
}


#pragma mark - Request delegate


-(BOOL) needsUpdate:(NSString*)configVersion {

    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString* currentVersion = infoDictionary[@"CFBundleShortVersionString"];

    if ([configVersion compare:currentVersion options:NSNumericSearch] == NSOrderedDescending) {
        DLog(@"Need to update [%@ != %@]", configVersion, currentVersion);
        return YES;
    }
    
    return NO;
}


- (void) requestDidFinish:(Request*)request withError:(NSError*)error
{
    isRequesting = NO;
    [SharedDelegate hideLoader];

    if (error != nil) {
        [SharedDelegate handleConfigurationRequestError];
    }
    else {
        NSError* parserError = nil;
        config = nil;
        config = [NSJSONSerialization JSONObjectWithData:request.responseData options:0 error:&parserError];

        if (parserError || !config || request.responseStatusCode != 200) {
            DLog(@"JSON parse error: %@", parserError);
            [SharedDelegate handleConfigurationRequestError];
        }
        else {
            DLog(@"%@", config);
            if ([self needsUpdate:config[kConfigRootKey][kConfigVersionsKey][kConfigIOSVersion]]) {
                [SharedDelegate handleVersionError];
            }
            else {
                isLoaded = YES;
                [[NSNotificationCenter defaultCenter] postNotificationName:didLoadConfigurationFile object:nil];
            }
        }
    }
}

@end
