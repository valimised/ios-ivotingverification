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
    SecTrustRef trust                       = protectionSpace.serverTrust;
    CFIndex numCerts                        = SecTrustGetCertificateCount(trust);
    NSMutableArray* _certs                  = [NSMutableArray arrayWithCapacity:numCerts];
    DLog(@"numcerts %ld", (long)numCerts);

    for (CFIndex idx = 0; idx < numCerts; ++idx) {
        SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, idx);
        DLog(@"%@", cert);
        [_certs addObject:CFBridgingRelease(cert)];
    }

    SecPolicyRef policy = SecPolicyCreateSSL(true,
                          (request.validHost ? (__bridge CFStringRef)request.validHost : NULL));
    OSStatus err = SecTrustCreateWithCertificates(CFBridgingRetain(_certs), policy, &trust);
    CFRelease(policy);

    if (err != noErr) {
        return nil;
    }

    NSData* _data1 = [[NSData alloc] initWithContentsOfFile:[[[NSBundle mainBundle] resourcePath]
                                     stringByAppendingString:CA_CERTIFICATE_FILE1]];

    if ([_data1 length] > 0) {
        DLog(@"Replacing system trust store with contents of %@", CA_CERTIFICATE_FILE1);
        SecCertificateRef mRootCert1 = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)_data1);
        NSArray* rootCerts = @[CFBridgingRelease(mRootCert1)];
        err = SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)rootCerts);
    }

    if (err == noErr) {
        SecTrustResultType trustResult;
        err = SecTrustEvaluate(trust, &trustResult);
        NSURLCredential* credential = [NSURLCredential credentialForTrust:trust];
        CFArrayRef pa = SecTrustCopyProperties(trust);
        DLog(@"errDataRef=%@", pa);

        if (pa != nil) {
            CFRelease(pa);
        }

        CFRelease(trust);
        DLog("%d", trustResult);
        bool trusted = (err == noErr) && (trustResult == kSecTrustResultProceed ||
                                          trustResult == kSecTrustResultUnspecified);

        if (trusted) {
            return credential;
        }
    }

    return nil;
}

- (void) request:(Request*)request didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge
    completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition disposition,
    NSURLCredential* credential))completionHandler
{
    if (![challenge.protectionSpace.authenticationMethod isEqualToString:
                                                           NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
    else {
        NSURLCredential* credential = [self analyzeChallenge:challenge request:request];

        if (credential != nil) {
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        }
        else {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
    }
}


@end
