//
//  ElgamalPub.h
//  VVK

#import <Foundation/Foundation.h>

@class Ballot;
@class Group;
@class Element;
@class Scalar;

@interface ElgamalPub : NSObject
{
    Group* group;
    Element* y;
    NSString* elId;
}

@property (atomic, readonly) Group* group;
@property (atomic, readonly) Element* y;
@property (atomic, readonly) NSString* elId;

- (id) init;

- (id) initWithPemString:(NSString*)pemStr;

- (Element*) decryptBallot:(Ballot*)ballot
                randomness:(Scalar*)randomness;

- (Element*) decryptCiphertextvBlindedMsg:(Element*)vBlindedMsg
                                   uBlind:(Element*)uBlind
                               randomness:(Scalar*)randomness;

@end
