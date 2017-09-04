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

@implementation Ballot

@synthesize name;
@synthesize vote;

- (id)initWithName:(NSString *)ballotName andVote:(ELGAMAL_CIPHER *)voteCipher;
{
    self = [super init];
    
    if (self)
    {
        name = ballotName;
        vote = voteCipher;
    }
    
    return self;
}

- (void)dealloc
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

- (id)initWithComponents:(in NSArray *)components
{
    self = [super init];
    
    if (self)
    {
        number = components[0];
        party = components[1];
        name = components[2];
    }
    
    return self;
}

- (void)dealloc
{
    name = nil;
    number = nil;
    party = nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<Candidate: %p> {name: %@, party: %@, number: %@}", self, name, party, number];
}

@end




@interface VoteContainer (Private)

- (void)presentError:(in NSString *)errorMessage;
- (void)downloadComplete;
- (void)tearDown:(TlsSocket*)stream;
- (void)closeSocket:(TlsSocket*)stream;

@end

@implementation VoteContainer
{
    TlsSocket* voteSocket;
    NSData* voteRpc;
    BOOL voteDownloaded;
    NSObject* lock;
    NSObject* writeLock;
    BOOL written;
    BOOL error;
}

@synthesize ballots;
@synthesize scanResult;

#pragma mark - Initialization

- (id)initWithScanResult:(QRScanResult *)result
{
    self = [super init];
    
    if (self)
    {
        scanResult = result;
        ballots = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    DLog(@"");
    
    scanResult = nil;
    ballots = nil;
}


#pragma mark - Public methods

- (void)download
{
    voteDownloaded = NO;
    error = NO;
    written = NO;
    [self downloadVote:[scanResult sessionId] logId:[scanResult logId]];
}

- (NSDictionary *)bruteForceVerification
{
    NSMutableDictionary * matchingCandidates = [NSMutableDictionary dictionary];

    ElgamalPub* pub = [[ElgamalPub alloc] initWithPemString:[[Config sharedInstance] publicKey]];
    if (!pub) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return nil;
    }
    
    for (Ballot* b in ballots)
    {
        NSString* m = [Crypto decryptVote:b.vote->cipher->b->data voteLen:b.vote->cipher->b->length withRnd:scanResult.rndSeed key:pub];
        if (m == NULL) {
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
            return nil;
        }
        NSArray* choiceSplit = [m componentsSeparatedByString:@"\x1F"];
        if ([choiceSplit count] != 3) {
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
            return nil;
        }
        [matchingCandidates setObject:[[Candidate alloc] initWithComponents:choiceSplit] forKey:b.name];
    }

    return matchingCandidates;
}

#pragma mark - Private methods

- (void)downloadVote:(NSString*)voteId logId:(NSString*)logId {
    NSDictionary* params = @{@"sessionid": logId, @"voteid": voteId};
    voteRpc = [JsonRpc createRequest:[JsonRpc METHOD_VERIFY] withParams:params];
    NSString* url = [[Config sharedInstance] getParameter:@"verification_url"][0];
    NSArray* urlParts = [url componentsSeparatedByString:@":"];
    voteSocket = [[TlsSocket alloc] initWithHost:@"verification.ivxv.invalid"
                                              ip:urlParts[0]
                                            port:[urlParts[1] integerValue]
                                    certStrArray:[[Config sharedInstance] getParameter:@"verification_tls"]];
    [voteSocket setDelegate:self];
    [voteSocket scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [voteSocket open];
}

- (void)downloadComplete
{
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
    NSData* containerData = [[NSData alloc] initWithBase64EncodedString:voteResp[@"result"][@"Vote"] options:0];
    NSData* ocspData = [[NSData alloc] initWithBase64EncodedString:voteResp[@"result"][@"Qualification"][@"ocsp"] options:0];
    NSData* regData = [[NSData alloc] initWithBase64EncodedString:voteResp[@"result"][@"Qualification"][@"tspreg"] options:0];
    
    if (containerData == nil || ocspData == nil || regData == nil) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    ElgamalPub* pub = [[ElgamalPub alloc] initWithPemString:[[Config sharedInstance] publicKey]];
    if (!pub) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    Bdoc* bdoc = [[Bdoc alloc] initWithData:containerData electionId:[pub elId]];
    if (![bdoc validateBdoc]) {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    NSArray* ocspCerts = [[Config sharedInstance] getParameter:@"ocsp_service_cert"];
    ASN1_GENERALIZEDTIME* ocsp_producedAt = nil;
    BOOL res = [OcspHelper verifyResp:ocspData responderCertData:ocspCerts requestedCert:bdoc.cert producedAt:ocsp_producedAt];
    if (!res) {
        DLog("Ocsp response verification failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    NSData* pkixCert = [[[Config sharedInstance] getParameter:@"tspreg_service_cert"] dataUsingEncoding:NSUTF8StringEncoding];
    NSData* collectorRegCert = [[[Config sharedInstance] getParameter:@"tspreg_client_cert"] dataUsingEncoding:NSUTF8StringEncoding];

    ASN1_GENERALIZEDTIME* pkix_genTime = nil;
    res = [PkixHelper verifyResp:regData collectorRegCert:collectorRegCert pkixCert:pkixCert data:[bdoc signatureValue] genTime:pkix_genTime];
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
    
    for (NSString* key in bdoc.votes) {
        NSData* vote = [bdoc.votes objectForKey:key];
        BIO* cBio = BIO_new_mem_buf([vote bytes], (int)[vote length]);
        ELGAMAL_CIPHER* c = d2i_ELGAMAL_CIPHER_bio(cBio, NULL);
        NSString* questionDesc = [[Config sharedInstance] electionForKey:key];
        if (!questionDesc) {
            questionDesc = key;
        }
        Ballot* ballot = [[Ballot alloc] initWithName:questionDesc andVote:c];
        [ballots addObject:ballot];
    }
    
    X509_NAME* name = X509_get_subject_name(bdoc.cert);
    int pos = X509_NAME_get_index_by_NID(name, NID_commonName, -1);
    X509_NAME_ENTRY* e = X509_NAME_get_entry(name, pos);

    NSString* signer = [[NSString alloc] initWithBytes:e->value->data length:e->value->length encoding:NSUTF8StringEncoding];

    NSString* verifyMessage = [[[[[Config sharedInstance] textForKey:@"lbl_vote_txt"]
      stringByAppendingString:@"\n"]
      stringByAppendingString:[[Config sharedInstance] textForKey:@"lbl_vote_signer"]]
      stringByAppendingString:signer];

    ALCustomAlertView * alert = [[ALCustomAlertView alloc] initWithOptions:@{kAlertViewMessage: verifyMessage,
                                                                             kAlertViewConfrimButtonTitle: [[Config sharedInstance] textForKey:@"btn_verify"],
                                                                             kAlertViewBackgroundColor: [[Config sharedInstance] colorForKey:@"main_window"],
                                                                             kAlertViewForegroundColor: [[Config sharedInstance] colorForKey:@"main_window_foreground"]}];
    
    [alert setDelegate:self];
    [alert setTag:1001];
    [alert show];
}

- (void)presentError:(in NSString *)errorMessage
{
    voteSocket = NULL;
    [SharedDelegate hideLoader];
    [SharedDelegate presentError:errorMessage];
}


#pragma mark - Custom alert view delegate

- (void)alertView:(ALCustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 1001 && buttonIndex == 1)
    {
        [SharedDelegate showLoaderWithClearStyle:NO];
        
        NSDictionary * results = [self bruteForceVerification];
        
        [SharedDelegate hideLoader];
        
        if (results)
        {
            [SharedDelegate presentVoteVerificationResults:results];
            
            results = nil;
        }
    }
}

#pragma mark - NSStream delefate

- (void) stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    BOOL shouldClose = NO;
    switch (eventCode) {
        case NSStreamEventEndEncountered: {
            DLog(@"NSStreamEventEndEncountered");

            if ([aStream isKindOfClass:[NSInputStream class]]) {
                shouldClose = YES;
                if (![((NSInputStream*) aStream) hasBytesAvailable]) {
                    break;
                }
            } else {
                [aStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                [aStream setDelegate:nil];
                [aStream close];
                break;
            }
        }
        case NSStreamEventHasBytesAvailable:
        {
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
        case NSStreamEventHasSpaceAvailable:
        {
            DLog(@"NSStreamEventHasSpaceAvailable");

            if (!written) {
                @synchronized (writeLock) {
                    if (!written) {
                        written = YES;
                        NSOutputStream* outStream = (NSOutputStream*) aStream;
                        SecTrustRef trust = (__bridge SecTrustRef)[outStream propertyForKey:(__bridge NSString *)kCFStreamPropertySSLPeerTrust];
                        trust = addAnchorToTrust(trust, [voteSocket certs]);
                        if (trust == NULL) {
                            [self tearDown:voteSocket];
                            break;
                        }
                        SecTrustResultType res = kSecTrustResultInvalid;
                        if (SecTrustEvaluate(trust, &res)) {
                            [self tearDown:voteSocket];
                            break;
                        }
                        
                        if (res != kSecTrustResultProceed && res != kSecTrustResultUnspecified) {
                            [self tearDown:voteSocket];
                        } else {
                            NSData* outData = voteRpc;
                            
                            [outStream write:[outData bytes] maxLength:[outData length]];
                        }
                    }
                }
            }
            break;
            
        }
        case NSStreamEventErrorOccurred:
        {
            DLog(@"NSStreamEventErrorOccurred: %@", [aStream streamError]);
            [self tearDown:voteSocket];
            break;
        }
        case NSStreamEventNone:
        {
            DLog(@"NSStreamEventNone");
            break;
        }
        case NSStreamEventOpenCompleted:
        {
            DLog(@"NSStreamEventOpenCompleted");
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

- (void) closeSocket:(TlsSocket*) socket
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
#ifdef PRE_10_6_COMPAT
    CFArrayRef oldAnchorArray = NULL;
    
    /* In OS X prior to 10.6, copy the built-in
     anchors into a new array. */
    if (SecTrustCopyAnchorCertificates(&oldAnchorArray) != errSecSuccess) {
        /* Something went wrong. */
        return NULL;
    }
    
    CFMutableArrayRef newAnchorArray = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, oldAnchorArray);
    CFRelease(oldAnchorArray);
#else
    /* In iOS and OS X v10.6 and later, just create an empty
     array. */
    CFMutableArrayRef newAnchorArray = CFArrayCreateMutable (kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
#endif
    
    CFArrayAppendArray(newAnchorArray, (__bridge CFArrayRef)trustedCerts, CFRangeMake(0, [trustedCerts count]));
    
    SecTrustSetAnchorCertificates(trust, newAnchorArray);
    
#ifndef PRE_10_6_COMPAT
    /* In iOS or OS X v10.6 and later, reenable the
     built-in anchors after adding your own.
     */
    SecTrustSetAnchorCertificatesOnly(trust, false);
#endif
    
    return trust;
}

void myCFHostClientCallBack(CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void* info) {
    
}

@end
