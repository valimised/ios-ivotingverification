//
//  Vote.m
//  VVK

#import "VoteContainer.h"
#import "AppDelegate.h"
#import "QRScanResult.h"
#import "Crypto.h"
#import "TlsSocket.h"
#import "JsonRpc.h"
#import "Bdoc.h"
#import "ElgamalPub.h"
#import "OcspHelper.h"
#import "PkixHelper.h"
#import "DNSResolver.h"
#import "NSMutableArray+Shuffle.h"

@implementation Ballot

@synthesize name;
@synthesize vote;

- (id) initWithName:(NSString*)ballotName andVote:(ELGAMAL_CIPHER*)voteCipher;
{
    self = [super init];

    if (self) {
        name = ballotName;
        vote = voteCipher;
    }

    return self;
}

- (void) dealloc
{
    DLog(@"");
    name = nil;
    vote = nil;
}

@end




@implementation Candidate

@synthesize name;
@synthesize party;
@synthesize number;

- (id) initWithComponents:(in NSArray*)components
{
    self = [super init];

    if (self) {
        number = components[0];
        party = components[1];
        name = components[2];
    }

    return self;
}

- (void) dealloc
{
    name = nil;
    number = nil;
    party = nil;
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"<Candidate: %p> {name: %@, party: %@, number: %@}", self, name,
                     party, number];
}

@end




@interface VoteContainer (Private)

- (void) presentError:(in NSString*)errorMessage;
- (void) downloadComplete;
- (void) tearDown:(TlsSocket*)stream;
- (void) closeSocket:(TlsSocket*)stream;
- (void) handleConnectionTimeout;
- (void) handleConnection;

@end

@implementation VoteContainer {
    TlsSocket* voteSocket;
    NSData* voteRpc;
    BOOL voteDownloaded;
    NSObject* lock;
    NSObject* writeLock;
    BOOL written;
    BOOL error;
    NSMutableArray* ipArray;
    NSEnumerator* ipEnumarator;
    NSTimer* connectionTimeoutTimer;
    double timeoutLen;
}

@synthesize ballots;
@synthesize scanResult;

#pragma mark - Initialization

- (id) initWithScanResult:(QRScanResult*)result
{
    self = [super init];

    if (self) {
        scanResult = result;
        ballots = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void) dealloc
{
    DLog(@"");
    [self stopConnectionTimeoutTimer];
    scanResult = nil;
    ballots = nil;
}


#pragma mark - Public methods

- (void) download
{
    voteDownloaded = NO;
    error = NO;
    written = NO;
    [self downloadVote:[scanResult sessionId] logId:[scanResult logId]];
}

- (NSDictionary*) ballotDecryptionWithRandomness
{
#if !(TARGET_APPSTORE_SCREENSHOTS)
    NSMutableDictionary* decryptedBallotPreferences = [NSMutableDictionary dictionary];
    ElgamalPub* publicEncryptionKey = [[ElgamalPub alloc] initWithPemString:[[Config sharedInstance]
                                                          publicKey]];

    if (!publicEncryptionKey) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return nil;
    }

    for (Ballot * ballot in ballots) {
        NSString* m = [Crypto decryptVote:ballot.vote->cipher->b->data
                              voteLen:ballot.vote->cipher->b->length
                              withRnd:scanResult.rndSeed
                              key:publicEncryptionKey];

        // TODO - should continue and show errors later
        if (m == NULL) {
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
            return nil;
        }

        NSArray* choiceSplit = [m componentsSeparatedByString:@"\x1F"];
#else
        NSString* m = @"0.101;Üksikkandidaadid;NIMI NIMESTE";
        NSArray* choiceSplit = [m componentsSeparatedByString:@";"];
#endif

        if ([choiceSplit count] != 3) {
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
            return nil;
        }

        [decryptedBallotPreferences setObject:[[Candidate alloc] initWithComponents:choiceSplit] forKey:
                                    ballot.name];
    }

    return decryptedBallotPreferences;
}

#pragma mark - Private methods

- (void) downloadVote:(NSString*)voteId logId:(NSString*)logId
{
#if !(TARGET_APPSTORE_SCREENSHOTS)
    NSDictionary* params = @ {@"sessionid": logId, @"voteid": voteId};
    voteRpc = [JsonRpc createRequest:[JsonRpc METHOD_VERIFY] withParams:params];
    self->ipArray = [[NSMutableArray alloc] init];
    NSArray* urls = [[Config sharedInstance] getParameter:@"verification_url"];
    DNSResolver* resolver;

    for (NSString * url in urls) {
        resolver = [[DNSResolver alloc] init];
        resolver.hostname = url;

        if (![resolver lookup]) {
            DLog("%@", resolver.error);
            continue;
        }

        [self->ipArray addObjectsFromArray:resolver.addresses];
    }

    [self->ipArray shuffle];
    self->ipEnumarator = [self->ipArray objectEnumerator];
    self->timeoutLen = ([[[Config sharedInstance] getParameter:@"con_timeout_1"] intValue] / 1000.0);
    [self handleConnection];
#else
    [SharedDelegate hideLoader];
    [self downloadComplete];
#endif
}

- (void) startConnectionTimeoutTimer:(NSTimeInterval)interval
{
    DLog("startcontimeout");
    [self stopConnectionTimeoutTimer];
    connectionTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                      target:self
                                      selector:@selector(handleConnection)
                                      userInfo:nil
                                      repeats:NO];
}

- (void) handleConnection
{
    DLog("handle");
    [self stopConnectionTimeoutTimer];

    if (voteSocket != nil) {
        [voteSocket close];
        voteSocket = nil;
    }

    NSString* addr = [ipEnumarator nextObject];

    if (!addr) {
        if (timeoutLen == ([[[Config sharedInstance] getParameter:@"con_timeout_1"] intValue] / 1000.0)) {
            timeoutLen = ([[[Config sharedInstance] getParameter:@"con_timeout_2"] intValue] / 1000.0);
            ipEnumarator = [ipArray objectEnumerator];
            [self handleConnection];
            return;
        }
        else {
            DLog(@"Couldn't connect to any collector service");
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
            return;
        }
    }
    else {
        [self connectTo:addr];
        [self startConnectionTimeoutTimer:timeoutLen];
    }
}

- (void) stopConnectionTimeoutTimer
{
    if (connectionTimeoutTimer) {
        [connectionTimeoutTimer invalidate];
        connectionTimeoutTimer = nil;
    }
}

- (void) connectTo:(NSString*)addr
{
    DLog("%@", addr);
    NSArray* addrParts = [addr componentsSeparatedByString:@":"];
    voteSocket = [[TlsSocket alloc] initWithHost:@"verification.ivxv.invalid"
                                    ip:addrParts[0]
                                    port:[addrParts[1] integerValue]
                                    certStrArray:[[Config sharedInstance] getParameter:@"verification_tls"]];
    [voteSocket setDelegate:self];
    [voteSocket scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [voteSocket open];
}

- (void) downloadComplete
{
#if !(TARGET_APPSTORE_SCREENSHOTS)
    NSDictionary* voteResp = [JsonRpc unmarshalResponse:[voteSocket data]];
    voteSocket = NULL;
    DLog("%@", voteResp);

    if (voteResp == nil) {
        DLog(@"Bad jsonRpc response from server");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    if (![voteResp[@"error"] isMemberOfClass:[NSNull class]]) {
        DLog(@"Vote jsonRpc resp with error: %@", voteResp[@"error"]);
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    // VOTE ----------------------------------
    NSData* containerData = [[NSData alloc] initWithBase64EncodedString:voteResp[@"result"][@"Vote"]
                                            options:0];
    NSData* ocspData = [[NSData alloc] initWithBase64EncodedString:
                                       voteResp[@"result"][@"Qualification"][@"ocsp"] options:0];
    NSData* regData = [[NSData alloc] initWithBase64EncodedString:
                                      voteResp[@"result"][@"Qualification"][@"tspreg"] options:0];

    if (containerData == nil || ocspData == nil || regData == nil) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    ElgamalPub* publicEncryptionKey = [[ElgamalPub alloc] initWithPemString:[[Config sharedInstance]
                                                          publicKey]];

    if (!publicEncryptionKey) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    Bdoc* bdoc = [[Bdoc alloc] initWithData:containerData electionId:[publicEncryptionKey elId]];

    if (![bdoc validateBdoc]) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    NSArray* ocspCerts = [[Config sharedInstance] getParameter:@"ocsp_service_cert"];

    if (ocspCerts == nil) {
        ocspCerts = [NSArray new];
    }

    ASN1_GENERALIZEDTIME* ocsp_producedAt = nil;
    BOOL res = [OcspHelper verifyResp:ocspData responderCertData:ocspCerts requestedCert:bdoc.cert
                           issuerCert:bdoc.issuer producedAt:ocsp_producedAt];

    if (!res) {
        DLog("Ocsp response verification failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    NSData* pkixCert = [[[Config sharedInstance] getParameter:@"tspreg_service_cert"] dataUsingEncoding
                                                 :NSUTF8StringEncoding];
    NSData* collectorRegCert = [[[Config sharedInstance] getParameter:@"tspreg_client_cert"]
                                                         dataUsingEncoding:NSUTF8StringEncoding];
    ASN1_GENERALIZEDTIME* pkix_genTime = nil;
    res = [PkixHelper verifyResp:regData collectorRegCert:collectorRegCert pkixCert:pkixCert data:[bdoc
                       signatureValue] genTime:pkix_genTime];

    if (!res) {
        DLog("Pkix response verification failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    int pday, psec;
    ASN1_TIME_diff(&pday, &psec, ocsp_producedAt, pkix_genTime);

    if (psec < 0) {
        DLog("PKIX predates OCSP");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    if (pday != 0 || psec > 60 * 15) {
        DLog("PKIX and OCSP timestamps too far apart");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    for (NSString * key in bdoc.votes) {
        NSData* vote = [bdoc.votes objectForKey:key];
        BIO* cBio = BIO_new_mem_buf([vote bytes], (int)[vote length]);
        ELGAMAL_CIPHER* cipherText = d2i_ELGAMAL_CIPHER_bio(cBio, NULL);
        NSString* questionDesc = [[Config sharedInstance] electionForKey:key];

        if (!questionDesc) {
            questionDesc = key;
        }

        Ballot* ballot = [[Ballot alloc] initWithName:questionDesc andVote:cipherText];
        [ballots addObject:ballot];
    }

    X509_NAME* name = X509_get_subject_name(bdoc.cert);
    char szOutCN[256] = {0};
    X509_NAME_get_text_by_NID(name, NID_commonName, szOutCN, 256);
    NSString* signer = [NSString stringWithUTF8String:szOutCN];

#else
    Ballot* ballot = [[Ballot alloc] initWithName:@"Keda valite?" andVote:@"cipherText"];
    [ballots addObject:ballot];
    NSString* signer = @"O'CONNEŽ-ŠUSLIK,MARY ÄNN,11412090004";
#endif

    NSString* verifyMessage = [[[[[Config sharedInstance] textForKey:@"lbl_vote_txt"]
                                                            stringByAppendingString:@"\n"]
                                                           stringByAppendingString:[[Config sharedInstance] textForKey:@"lbl_vote_signer"]]
                                                          stringByAppendingString:signer];
    ALCustomAlertView* alert = [[ALCustomAlertView alloc] initWithOptions:@ {kAlertViewMessage:verifyMessage,
                                                          kAlertViewConfrimButtonTitle:[[Config sharedInstance] textForKey:@"btn_verify"],
                                                          kAlertViewBackgroundColor:[[Config sharedInstance] colorForKey:@"main_window"],
                                                          kAlertViewForegroundColor:[[Config sharedInstance] colorForKey:@"main_window_foreground"]
                                                                            }];
    [alert setDelegate:self];
    [alert setTag:1001];
    [alert show];
}

- (void) presentError:(in NSString*)errorMessage
{
    voteSocket = NULL;
    [SharedDelegate hideLoader];
    [SharedDelegate presentError:errorMessage];
}


#pragma mark - Custom alert view delegate

- (void) alertView:(ALCustomAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 1001 && buttonIndex == 1) {
        [SharedDelegate showLoaderWithClearStyle:NO];
        NSDictionary* results = [self ballotDecryptionWithRandomness];
        [SharedDelegate hideLoader];

        if (results) {
            [SharedDelegate presentVoteVerificationResults:results];
            results = nil;
        }
    }
}

#pragma mark - NSStream delegate

- (void) stream:(NSStream*)aStream handleEvent:(NSStreamEvent)eventCode
{
    BOOL shouldClose = NO;

    switch (eventCode) {
    case NSStreamEventEndEncountered: {
            DLog(@"NSStreamEventEndEncountered");

            if ([aStream isKindOfClass:[NSInputStream class]]) {
                shouldClose = YES;

                if (![((NSInputStream*) aStream) hasBytesAvailable]) {
                    break;
                }
            }
            else {
                [aStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                [aStream setDelegate:nil];
                [aStream close];
                break;
            }
        }

    case NSStreamEventHasBytesAvailable: {
            DLog(@"NSStreamEventHasBytesAvailable");
            NSInputStream* inStream = (NSInputStream*) aStream;
            NSMutableData* data = [voteSocket data];
            int len = 1024;
            uint8_t buffer[len];

            while ([inStream hasBytesAvailable]) {
                int bytesRead = (int)[inStream read:buffer maxLength:len];
                [data appendBytes:buffer length:bytesRead];
            }

            break;
        }

    case NSStreamEventHasSpaceAvailable: {
            DLog(@"NSStreamEventHasSpaceAvailable");

            if (!written) {
                @synchronized (writeLock) {
                    if (!written) {
                        written = YES;
                        NSOutputStream* outStream = (NSOutputStream*) aStream;
                        SecTrustRef trust = (__bridge SecTrustRef)[outStream propertyForKey:(__bridge NSString*)
                                                      kCFStreamPropertySSLPeerTrust];
                        trust = addAnchorToTrust(trust, [voteSocket certs]);

                        if (trust == NULL) {
                            DLog(@"addAnchorToTrust failed");
                            [self tearDown:voteSocket];
                            break;
                        }

                        SecTrustResultType res = kSecTrustResultInvalid;

                        if (SecTrustEvaluate(trust, &res)) {
                            DLog(@"SecTrustEvaluate failed");
                            [self tearDown:voteSocket];
                            break;
                        }

                        CFArrayRef pa = SecTrustCopyProperties(trust);
                        DLog(@"errDataRef=%@", pa);

                        if (pa != nil) {
                            CFRelease(pa);
                        }

                        if (res != kSecTrustResultProceed && res != kSecTrustResultUnspecified) {
                            DLog(@"TrustResult not supported %d", res);
                            [self tearDown:voteSocket];
                        }
                        else {
                            NSData* outData = voteRpc;
                            [outStream write:[outData bytes] maxLength:[outData length]];
                        }
                    }
                }
            }

            break;
        }

    case NSStreamEventErrorOccurred: {
            DLog(@"NSStreamEventErrorOccurred: %@", [aStream streamError]);
            [self tearDown:voteSocket];
            break;
        }

    case NSStreamEventNone: {
            DLog(@"NSStreamEventNone");
            break;
        }

    case NSStreamEventOpenCompleted: {
            DLog(@"NSStreamEventOpenCompleted");
            [self stopConnectionTimeoutTimer];
            break;
        }
    }

    if (shouldClose) {
        [aStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [aStream setDelegate:nil];
        [aStream close];
        @synchronized (lock) {
            if (!voteDownloaded && !error) {
                voteDownloaded = YES;
                [SharedDelegate hideLoader];
                [self closeSocket:voteSocket];
                [self downloadComplete];
            }
        }
    }
}

- (void) tearDown:(TlsSocket*)socket
{
    @synchronized (lock) {
        error = YES;
    }
    [self closeSocket:socket];
    [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
}

- (void) closeSocket:(TlsSocket*)socket
{
    [[socket inStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[socket inStream] setDelegate:nil];
    [[socket inStream] close];
    [[socket outStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[socket outStream] setDelegate:nil];
    [[socket outStream] close];
}

SecTrustRef addAnchorToTrust(SecTrustRef trust, NSArray* trustedCerts)
{
    DLog(@"%@", trustedCerts);
    CFMutableArrayRef newAnchorArray = CFArrayCreateMutable (kCFAllocatorDefault, 0,
                                       &kCFTypeArrayCallBacks);
    CFArrayAppendArray(newAnchorArray, (__bridge CFArrayRef)trustedCerts,
                       CFRangeMake(0, [trustedCerts count]));
    OSStatus res = SecTrustSetAnchorCertificates(trust, newAnchorArray);
    res = SecTrustSetAnchorCertificatesOnly(trust, false);
    return trust;
}

@end
