//
//  Vote.m
//  VVK
//
//  Created by Eigen Lenk on 1/30/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "VoteContainer.h"
#import "Request.h"
#import "RegexMatcher.h"
#import "AppDelegate.h"
#import "QRScanResult.h"
#import "Crypto.h"
#import "AuthenticationChallengeHandler.h"

@implementation Ballot

@synthesize name;
@synthesize hex;

- (id)initWithName:(NSString *)ballotName andHex:(NSString *)hexCode
{
    self = [super init];
    
    if (self)
    {
        name = ballotName;
        hex = hexCode;
    }
    
    return self;
}

- (void)dealloc
{
    DLog(@"");

    name = nil;
    hex = nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<Election: %p> {name: %@, hex: %@}", self, name, hex];
}

@end




@implementation Candidate

@synthesize name;
@synthesize party;
@synthesize number;
@synthesize ballot;

- (id)initWithComponents:(in NSArray *)components andElection:(in Ballot *)election
{
    self = [super init];
    
    if (self)
    {
        name = components[4];
        number = components[3];
        
        if ([components count] > 4) {
            party = components[5];
        } else {
            party = nil;
        }
        
        ballot = election;
    }
    
    return self;
}

- (void)dealloc
{
    name = nil;
    number = nil;
    party = nil;
    ballot = nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<Candidate: %p> {name: %@, party: %@, number: %@}", self, name, party, number];
}

@end




@interface VoteContainer (Private)

- (void)parseVerificationRequestResult:(in NSString *)resultString;
- (void)parseElections:(in NSArray *)components;
- (void)parseCandidates:(in NSArray *)components;
- (void)presentError:(in NSString *)errorMessage;

@end

@implementation VoteContainer

@synthesize ballots;
@synthesize scanResult;
@synthesize candidates;

#pragma mark - Initialization

- (id)initWithScanResult:(QRScanResult *)result
{
    self = [super init];
    
    if (self)
    {
        scanResult = result;
    }
    
    return self;
}

- (void)dealloc
{
    DLog(@"");
    
    scanResult = nil;
    ballots = nil;
    candidates = nil;
    versionNumber = -1;
    controlState = -1;
}


#pragma mark - Public methods

- (void)download
{
    NSURL * containerDownloadURL = [NSURL URLWithString:[[Config sharedInstance] getParameter:@"app_url"] /*@"https://portal.cyber.ee/hes-verify-vote.cgi"*/];
    
    Request * request = [[Request alloc] initWithURL:containerDownloadURL
                                             options:@{kRequestType: @"POST",
                                                       kRequestPOST: @{@"verify": scanResult.voteIdentificator}}];
    
    request.delegate = self;
    request.authenticationDelegate = [AuthenticationChallengeHandler sharedInstance];
    request.validHost = containerDownloadURL.host;
    
    [request start];
}

- (NSArray *)bruteForceVerification
{
    NSArray * matchingCandidates = [NSArray array];
    
    if (![Crypto initPublicKey:[[Config sharedInstance] publicKey]])
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        
        return nil;
    }
    
    for (VerificationEntry * v in scanResult.verificationEntries)
    {
        if ([RegexMatcher is40Characters:v.hex] == NO)
        {
            [Crypto clearPublicKey];
            
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
            
            return nil;
        }
        
        Ballot * ballot = ballots[v.electionIdentificator];
        
        NSString * encryptedVoteToCompare = ballot.hex;
      
        for (Candidate * candidate in candidates)
        {
            if ([candidate.ballot.name isEqualToString:ballot.name] == NO)
            {
                DLog(@"Different ballot name: %@ VS. %@", candidate.ballot.name, ballot.name);
                continue;
            }

            // DLog(@"");
            // DLog(@"Candidate: %@", candidate.name);
            
            NSString * votePlaintext = [NSString stringWithFormat:@"%d\n%@\n%@\n", versionNumber, v.electionIdentificator, candidate.number];
            NSString * encryptedVote = [Crypto encryptVote:votePlaintext
                                                  withSeed:v.hex];

            if (encryptedVote && [[encryptedVote lowercaseString] isEqualToString:encryptedVoteToCompare])
            {
                matchingCandidates = [matchingCandidates arrayByAddingObject:candidate];
            }
        }
    }
    
    [Crypto clearPublicKey];
    
    if ([matchingCandidates count] == 0)
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_verification_message"]];
        
        return nil;
    }

    return matchingCandidates;
}


#pragma mark - Request delegate

- (void)requestDidFinish:(Request *)request
{
    [SharedDelegate hideLoader];
    
    DLog(@"request.responseStatusCode = %d", request.responseStatusCode);
    
    if (request.responseStatusCode != 200)
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
    }
    else
    {
        [self parseVerificationRequestResult:[[NSString alloc] initWithData:request.responseData encoding:NSUTF8StringEncoding]];
    }
}

- (void)request:(Request *)request didFailWithError:(NSError *)error
{
    [SharedDelegate hideLoader];
    
    if (error.code == NSURLErrorNotConnectedToInternet)
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"no_network_message"]];
    }
    else
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
    }
    
    return;
}


#pragma mark - Private methods

- (void)parseVerificationRequestResult:(in NSString *)resultString
{
    DLog(@"|%@|", resultString);
    
    if (resultString == nil || [resultString length] == 0)
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        
        return;
    }
    
    NSArray * components = [resultString componentsSeparatedByString:@"\n"];
    
    DLog(@"components = %@", components);
    
    if ([components count] < 2)
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        
        return;
    }
    
    // Read and assert version number

    if ([RegexMatcher isSingleOrDoubleDigit:components[0]] == NO)
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        
        return;
    }
    
    versionNumber = [components[0] integerValue];

    
    
    // Read and assert control state (0 = OK, 1 = ERROR)
    
    if ([RegexMatcher isSingleDigit:components[1]] == NO)
    {
        [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
        
        return;
    }
    
    controlState = [components[1] integerValue];
    
    
    
    
    // State is OK
    if (controlState == 0)
    {
        if ([components count] < 4)
        {
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
            
            return;
        }

        [self parseElections:components];
        [self parseCandidates:components];
        
        if ([ballots count] == 0 || [candidates count] == 0)
        {
            [self presentError:[[Config sharedInstance] errorMessageForKey:@"bad_server_response_message"]];
            
            return;
        }
        
        ALCustomAlertView * alert = [[ALCustomAlertView alloc] initWithOptions:@{kAlertViewMessage: [[Config sharedInstance] textForKey:@"verify_message"],
                                                                                 kAlertViewConfrimButtonTitle: [[Config sharedInstance] textForKey:@"btn_verify"],
                                                                                 kAlertViewBackgroundColor: [[Config sharedInstance] colorForKey:@"main_window"],
                                                                                 kAlertViewForegroundColor: [[Config sharedInstance] colorForKey:@"main_window_foreground"]}];
        
        [alert setDelegate:self];
        [alert setTag:1001];
        [alert show];
    }
    // State indicates an error
    else
    {
        NSString * errorMessage = components[2];
        
        [self presentError:errorMessage];
    }
    
    return;
}




- (void)parseElections:(in NSArray *)components
{
    NSMutableDictionary * _ballots = [NSMutableDictionary dictionary];
    
    ballots = [[NSDictionary alloc] init];
    
    NSUInteger numberOfElections = [[components[2] componentsSeparatedByString:@"\t"] count];
    
    for (NSUInteger i = 0; i < numberOfElections; ++i)
    {
        NSString * electionRow = components[3 + i];
        
        if ([electionRow length] == 0)
            continue;
        
        NSArray * electionComponents = [electionRow componentsSeparatedByString:@"\t"];
        
        if ([electionComponents count] == 0)
            continue;

        Ballot * ballot = [[Ballot alloc] initWithName:electionComponents[0] andHex:electionComponents[1]];
        
        [_ballots setObject:ballot forKey:electionComponents[0]];
        
        ballot = nil;
    }
    
    ballots = _ballots;
    
    _ballots = nil;
}

- (void)parseCandidates:(in NSArray *)components
{
    candidates = [[NSArray alloc] init];
    
    NSUInteger i = (2 + [ballots count] + 1 + 1);
    
    for (; i<components.count; ++i)
    {
        if ([components[i] length] == 0)
            continue;
        
        NSArray * rowComponents = [components[i] componentsSeparatedByString:@"\t"];
        
        Ballot * ballot = ballots[rowComponents[0]];
        
        Candidate * candidate = [[Candidate alloc] initWithComponents:rowComponents andElection:ballot];
        
        candidates = [candidates arrayByAddingObject:candidate];
        
        candidate = nil;
    }
}

- (void)presentError:(in NSString *)errorMessage
{
    [SharedDelegate presentError:errorMessage];
    
    // [[NSNotificationCenter defaultCenter] postNotificationName:shouldRestartApplicationState object:nil];
}


#pragma mark - Custom alert view delegate

- (void)alertView:(ALCustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 1001 && buttonIndex == 1)
    {
        [SharedDelegate showLoaderWithClearStyle:NO];
        
        NSArray * results = [self bruteForceVerification];
        
        [SharedDelegate hideLoader];
        
        if (results)
        {
            [SharedDelegate presentVoteVerificationResults:results];
            
            results = nil;
        }
    }
}

@end
