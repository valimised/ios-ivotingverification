//
//  Config.m
//  iVotingVerification

#import "Config.h"
#import "Request.h"
#import "UIColor+Hex.h"
#import "AppDelegate.h"
#import "AuthenticationChallengeHandler.h"


@interface Config ()
- (void)handleRequestError;
@end


@implementation Config

@synthesize isLoaded;

+ (Config *)sharedInstance
{
    static Config *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Config alloc] init];
    });
    
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        isLoaded = NO;
    }
    
    return self;
}

#pragma mark - Public methods

- (void)requestRemoteConfigurationFile
{
    if (isRequesting) {
        return;
    }
    
    __weak NSString * bundleConfigPath = [[NSBundle mainBundle] pathForResource:@"config" ofType:@"txt"];
    
    NSString * bundleConfigContents = [NSString stringWithContentsOfFile:bundleConfigPath encoding:NSUTF8StringEncoding error:nil];
    
    NSURL * configURL = [NSURL URLWithString:bundleConfigContents];
    
    Request * request = [[Request alloc] initWithURL:configURL];
    
    request.delegate = self;
    request.authenticationDelegate = [AuthenticationChallengeHandler sharedInstance];
    request.validHost = configURL.host;
    
    [SharedDelegate showLoaderWithClearStyle:YES];
    
    isRequesting = YES;
    
    [request start];
    
    return;
}

- (NSString *)errorMessageForKey:(NSString *)key
{
    return config[kConfigRootKey][kConfigErrorsKey][key];
}

- (NSString *)textForKey:(NSString *)key
{
    NSString * result = config[kConfigRootKey][kConfigTextsKey][key];
    
    if (!result) {
        result = key;
    }
    
    return result;
}

- (UIColor *)colorForKey:(NSString *)key
{
    return [UIColor colorWithHexString:config[kConfigRootKey][kConfigColorsKey][key]];
}

- (id)getParameter:(NSString *)key
{
    return config[kConfigRootKey][kConfigParamsKey][key];
}

- (NSString *)publicKey
{
    return config[kConfigRootKey][kConfigParamsKey][kPublicKeyKey];
}

- (NSString *)electionForKey:(NSString *)key
{
    return config[kConfigRootKey][kConfigElectionsKey][key];
}


#pragma mark - Request delegate

- (void)requestDidFinish:(Request *)request
{
    isRequesting = NO;
    
    [SharedDelegate hideLoader];
    
    NSError * parserError = nil;
    
    config = nil;
    
    config = [NSJSONSerialization JSONObjectWithData:request.responseData options:0 error:&parserError];
    
    if (parserError || !config || request.responseStatusCode != 200)
    {
        DLog(@"JSON parse error: %@", parserError);
        
        [self handleRequestError];
        
        return;
    }
    
    DLog(@"%@", config);
    
    isLoaded = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:didLoadConfigurationFile object:nil];
}

- (void)request:(Request *)request didFailWithError:(NSError *)error
{
    isRequesting = NO;
    
    [SharedDelegate hideLoader];
    
    [self handleRequestError];
}


#pragma mark - Private methods

- (void)handleRequestError
{
    ALCustomAlertView * alert = [[ALCustomAlertView alloc] initWithOptions:@{kAlertViewTitle: @"Viga",
                                                                             kAlertViewMessage: @"Konfiguratsiooni laadimine ebaõnnestus.",
                                                                             kAlertViewConfrimButtonTitle: @"Proovi uuesti",
                                                                             kAlertViewBackgroundColor: [UIColor colorWithHexString:@"#FF0000"],
                                                                             kAlertViewForegroundColor: [UIColor colorWithHexString:@"#FFFFFF"]}];
    
    [alert setDelegate:self];
    [alert setTag:1002];
    [alert show];
}


#pragma mark - Custom alert view delegate

- (void)alertView:(ALCustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Retry configuration loading
    if (alertView.tag == 1002 && buttonIndex == 1)
    {
        [self requestRemoteConfigurationFile];
    }
}

@end
