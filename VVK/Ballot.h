//
//  Ballot.h
//  VVK

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

- (id) initWithName:(NSString*)ballotName andVote:(NSData*)vote;

@end
