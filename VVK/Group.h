//
//  ElgamalPub.h
//  VVK

#import <Foundation/Foundation.h>

@class Ballot;
@class Scalar;
@class Element;

@interface Group : NSObject
{
}

- (id) init;

- (void) dealloc;

- (Element*) generator;

- (Element*) elementOfASN1:(NSData*)data;

- (Ballot*) decodeBallotWithName:(NSString*)ballotName
                      ciphertext:(NSData*)ciphertext;
@end

@interface Element : NSObject
{
}

- (id) init;

- (void) dealloc;

- (Element*) scaleWithScalar:(Scalar*) scalar;

- (Element*) operationWithElement:(Element*) other;

- (Element*) inverse;

- (bool) equalsWithElement:(Element*) other;

- (NSString*) decode;

@end
