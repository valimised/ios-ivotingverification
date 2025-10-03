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
        defaultErrorKeyValues = [self setDefaultErrorValues];
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

- (NSString*) errorTitleForKey:(NSString*)key
{
    return config[kConfigRootKey][kConfigErrorsKey][key] ?: defaultErrorKeyValues[key];
}

- (NSString*) errorMessageForKey:(NSString*)key
{
    return config[kConfigRootKey][kConfigErrorsKey][key] ?: defaultErrorKeyValues[key];
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
    NSString* hexString = config[kConfigRootKey][kConfigColorsKey][key];
    return hexString != nil ? [UIColor colorWithHexString: hexString] : UIColor.clearColor;
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
        if (error.code == NSURLErrorNotConnectedToInternet) {
            [SharedDelegate handleNetworkError];
        } else {
            [SharedDelegate handleConfigurationRequestError];
        }
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

#pragma mark - Private methods

- (NSDictionary *) setDefaultErrorValues
{
    return @{
        @"no_network_message": @"Palun veenduge, et nutiseadme internetiühendus on aktiivne",
        @"get_config_message": @"Seadistuse laadimine ebaõnnestus",
        @"problem_qrcode_message": @"QR-koodi ei õnnestunud tuvastada",
        @"bad_server_response_message": @"Tehniline viga, palun teavitage valimiste korraldajat abi@valimised.ee",
        @"bad_device_message": @"Seadmel puudub kaamera, verifitseerimist ei ole võimalik läbi viia",
        @"bad_verification_message": @"Valiku tuvastamine ebaõnnestus",
        @"bad_config_message": @"Seadistuse viga",
        @"bad_version_message": @"Rakenduse versioon ei ole ajakohane, palun uuendage oma rakendust",
        @"send_server_request_message": @"Serveriga ühendumine ebaõnnestus, kontrollige internetiühendust või teavitage valimiste korraldajat abi@valimised.ee",
        @"error_title_default": @"Viga",
        @"error_title_bad_version": @"Rakenduse versiooni viga",
    };
}

@end
