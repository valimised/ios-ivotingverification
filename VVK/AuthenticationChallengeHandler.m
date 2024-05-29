//
//  AuthenticationChallengeHandler.m
//  VVK

#import "AuthenticationChallengeHandler.h"

@implementation AuthenticationChallengeHandler

+ (AuthenticationChallengeHandler*) sharedInstance
{
    static AuthenticationChallengeHandler* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^ {
        sharedInstance = [[AuthenticationChallengeHandler alloc] init];
    });
    return sharedInstance;
}


#pragma mark - Request authentication delegate

- (NSURLCredential*) analyzeChallenge:(NSURLAuthenticationChallenge*)challenge request:
    (Request*)request
{
    NSURLProtectionSpace* protectionSpace  = challenge.protectionSpace;
    SecTrustRef trust = protectionSpace.serverTrust;
    CFArrayRef certs = SecTrustCopyCertificateChain(trust);

    SecPolicyRef policy = SecPolicyCreateSSL(true, (request.validHost ? (__bridge CFStringRef)request.validHost : NULL));

    OSStatus err = SecTrustCreateWithCertificates(certs, policy, &trust);
    CFRelease(policy);

    if (err != noErr) {
        return nil;
    }

    NSURLCredential* credential = [NSURLCredential credentialForTrust:trust];

    CFErrorRef *error = nil;
    BOOL isTrusted = SecTrustEvaluateWithError(trust, error);

    CFRelease(trust);

    if (isTrusted) {
        return credential;
    }

    return nil;
}

- (void) request:(Request*)request didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge
    completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition disposition,
    NSURLCredential* credential))completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (![challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            });
        }
        else {
            NSURLCredential* credential = [self analyzeChallenge:challenge request:request];

            if (credential != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
                });
            }
        }
    });
}

@end
