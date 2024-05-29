//  VoteContainer.m
//  VVK

#import "VoteContainer.h"
#import "Ballot.h"
#import "Candidate.h"
#import "AppDelegate.h"
#import "QRScanResult.h"
#import "Crypto.h"
#import "IVXVRequest.h"
#import "JsonRpc.h"
#import "Bdoc.h"
#import "ElgamalPub.h"
#import "OcspHelper.h"
#import "PkixHelper.h"
#import "DNSResolver.h"
#import "NSMutableArray+Shuffle.h"
#import "C.h"

typedef NS_ENUM(NSInteger, PhaseEnum) {
    Phase1,
    Phase2,
    Phase3
};

@implementation VoteContainer {
    PhaseEnum phase;
    IVXVRequest *ivxvHandler;
    NSData* voteRpc;
    NSMutableArray* ipArray;
    NSEnumerator* ipEnumarator;
    int timeoutLen;
}

@synthesize ballots;
@synthesize scanResult;
@synthesize choiceList;

#pragma mark - Initialization

- (id) initWithScanResult:(QRScanResult*)result
{
    self = [super init];
    scanResult = result;
    ballots = [[NSMutableArray alloc] init];
    return self;
}

- (void) dealloc
{
    scanResult = nil;
    ballots = nil;
    choiceList = nil;
}

#pragma mark - Public methods

- (void) download
{
#if !(TARGET_APPSTORE_SCREENSHOTS)
    [self downloadVote:[scanResult sessionId] logId:[scanResult logId]];
#else
    [SharedDelegate hideLoader];
    [self downloadComplete];
#endif
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
                              c1Data:ballot.vote->cipher->a->data
                              c1Len:ballot.vote->cipher->a->length
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
    phase = Phase1;
    [self initNextDownloadPhase];
}


- (void) initNextDownloadPhase
{
    switch (phase) {

        case Phase1:
            self->timeoutLen = ([[[Config sharedInstance] getParameter:@"con_timeout_1"] intValue] / 1000.0);
            phase = Phase2;
            break;

        case Phase2:
            self->timeoutLen = ([[[Config sharedInstance] getParameter:@"con_timeout_2"] intValue] / 1000.0);
            phase = Phase3;
            break;

        case Phase3:
            DLog(@"Couldn't connect to any collector service");
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
            return;
    }

    self->ipEnumarator = [self->ipArray objectEnumerator];
    [self handlePhaseConnection];
}

- (void) handlePhaseConnection
{
    NSString* connStr = [ipEnumarator nextObject];
    NSString *sniStr = [[Config sharedInstance] getParameter:@"verification_sni"];

    DLog("%@", connStr);
    if (!ivxvHandler) {
        ivxvHandler = [[IVXVRequest alloc] initWithCerts:[[Config sharedInstance] getParameter:@"verification_tls"]];
    }

    [ivxvHandler resetWithTimeout:self->timeoutLen];

    if (connStr) {
        [ivxvHandler sendHandshake:connStr sniStr:sniStr completion:^(NSError * _Nullable error) {
            if (error == nil) {
                [self->ivxvHandler sendRequest:self->voteRpc completion:^(NSData * _Nullable responseData, NSError * _Nullable error) {
                    [SharedDelegate hideLoader];
                    if (!error) {
                        [self downloadCompleteSuccess:responseData];
                    }
                    else {
                        DLog(@"Couldn't connect to any collector service");
                        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
                        return;
                    }
                }];
            }
            else {
                [self handlePhaseConnection];
            }
        }];
    } else {
        [self initNextDownloadPhase];
    }
}

- (void) downloadCompleteSuccess:(in NSData *)data
{
#if !(TARGET_APPSTORE_SCREENSHOTS)
    NSDictionary* voteResp = [JsonRpc unmarshalResponse:data];
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
    choiceList = [[ChoiceList alloc] initWithBase64:voteResp[@"result"][@"ChoicesList"]];

    if (containerData == nil || ocspData == nil || regData == nil || choiceList == nil) {
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

    if (pday != 0) {
        DLog("PKIX and OCSP timestamps are days apart");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    if (psec < 0) {
        DLog("PKIX predates OCSP");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    if (psec > 60 * 5) {
        DLog("PKIX and OCSP timestamps too far apart");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    for (NSString * key in bdoc.votes) {
        NSData* vote = [bdoc.votes objectForKey:key];
        NSString* questionDesc = [[Config sharedInstance] electionForKey:key];

        if (!questionDesc) {
            questionDesc = key;
        }

        Ballot* ballot = [[Ballot alloc] initWithName:questionDesc andVote:vote];
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
                                                          kAlertViewBackgroundColor:[[C sharedInstance] mainWindow],
                                                          kAlertViewForegroundColor:[[C sharedInstance] mainWindowForeground]
                                                                            }];
    [alert setDelegate:self];
    [alert setTag:1001];
    [alert show];
}

- (void) presentError:(in NSString*)errorMessage
{
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
            __block bool success = true;
            [results enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
                if (![choiceList isValidCandidate:value]) {
                    success = false;
                }
            }];

            if (success) {
                [SharedDelegate presentVoteVerificationResults:results];
                results = nil;
            } else {
                [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
            }
        }
    }
}

@end
