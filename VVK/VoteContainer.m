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
#import "Scalar.h"
#import "Group.h"
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
        DLog("Public key alloc failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_config_message"]];
        return nil;
    }

    Scalar *randomness = [[Scalar alloc] initWithBytes:scanResult.rndSeed
                                                 group:publicEncryptionKey.group];

    for (Ballot * ballot in ballots) {

        Element* m = [publicEncryptionKey decryptBallot:ballot
                                             randomness:randomness];
        // TODO - should continue and show errors later
        if (m == NULL) {
            DLog("Ballot decryption failed");
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
            return nil;
        }

        NSString *decoded = [m decode];

        if (decoded == NULL) {
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
            return nil;
        }

#else
        NSString* m = @"000.101";
#endif

        Candidate *cand = [choiceList findCandidate:decoded];

        if (!cand) {
            DLog("Choice not in choices list");
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
            return nil;
        }

        [decryptedBallotPreferences setObject:cand forKey:ballot.name];
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
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"send_server_request_message"]];
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
                        [self presentError:[[Config sharedInstance] errorMessageForKey:@"send_server_request_message"]];
                        return;
                    }
                }];
            }
            else {
                DLog(@"ERROR: %@", error);
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
        DLog("Vote data invalid");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_config_message"]];
        return;
    }

    ElgamalPub* publicEncryptionKey = [[ElgamalPub alloc] initWithPemString:[[Config sharedInstance]
                                                          publicKey]];

    if (!publicEncryptionKey) {
        DLog("Public key alloc failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_config_message"]];
        return;
    }

    Bdoc* bdoc = [[Bdoc alloc] initWithData:containerData electionId:[publicEncryptionKey elId]];

    if (![bdoc validateBdoc]) {
        DLog("Bdoc validation failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    NSArray* ocspCerts = [[Config sharedInstance] getParameter:@"ocsp_service_cert"];

    if (ocspCerts == nil) {
        ocspCerts = [NSArray new];
    }

    OcspHelper* ocsp = [[OcspHelper alloc] initWithData:ocspData];

    if (ocsp == nil) {
        DLog("OCSP alloc failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    BOOL res = [ocsp verifyResp:ocspCerts requestedCert:bdoc.cert issuerCert:bdoc.issuer];

    if (!res) {
        DLog("Ocsp response verification failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    NSData* pkixCert = [[[Config sharedInstance] getParameter:@"tspreg_service_cert"] dataUsingEncoding
                                                 :NSUTF8StringEncoding];
    NSData* collectorRegCert = [[[Config sharedInstance] getParameter:@"tspreg_client_cert"]
                                                         dataUsingEncoding:NSUTF8StringEncoding];

    PkixHelper* pkix = [[PkixHelper alloc] initWithData:regData];

    if (pkix == nil) {
        DLog("PKIX alloc failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    res = [pkix verifyResp:collectorRegCert pkixCert:pkixCert data:[bdoc signatureValue]];

    if (!res) {
        DLog("Pkix response verification failed");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    res = [ pkix compareWithOCSP:ocsp maxdiff:15 ];

    if (!res) {
        DLog("PKIX and OCSP timestamps are days apart");
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        return;
    }

    for (NSString * key in bdoc.votes) {
        NSData* vote = [bdoc.votes objectForKey:key];
        NSString* questionDesc = [[Config sharedInstance] electionForKey:key];

        if (!questionDesc) {
            questionDesc = key;
        }

        Ballot* ballot = [publicEncryptionKey.group decodeBallotWithName:questionDesc
                                                              ciphertext:vote];
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
    [alert setTag:TAG_VOTE_SIGNER_WINDOW];
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
            [SharedDelegate presentVoteVerificationResults:results];
            results = nil;
        }
    }
}

@end
