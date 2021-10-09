//
//  Vote.h
//  VVK

#import <Foundation/Foundation.h>

#import "ALCustomAlertView.h"
#import "ElGamalCiphertext.h"

@interface Ballot : NSObject
{
@private
    __strong NSString* name;
    ELGAMAL_CIPHER* vote;
}

#pragma mark - Properties

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) ELGAMAL_CIPHER* vote;

#pragma mark - Methods

- (id) initWithName:(NSString*)ballotName andVote:(ELGAMAL_CIPHER*)vote;

@end


#pragma mark -

@interface Candidate : NSObject
{
    __strong NSString* name;
    __strong NSString* party;
    __strong NSString* number;
}

#pragma mark - Properties

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* party;
@property (nonatomic, readonly) NSString* number;

#pragma mark - Methods

- (id) initWithComponents:(NSArray*)components;

@end


#pragma mark -

@class QRScanResult;

@interface VoteContainer : NSObject <ALCustomAlertViewDelegate, NSStreamDelegate>
{
@private
    __strong QRScanResult* scanResult;
    __strong NSMutableArray* ballots;
}

#pragma mark - Properties

@property (nonatomic, readonly) QRScanResult* scanResult;
@property (nonatomic, readonly) NSMutableArray* ballots;

#pragma mark - Methods

- (id) initWithScanResult:(QRScanResult*)result;

- (void) download;

- (NSDictionary*) ballotDecryptionWithRandomness;

@end
