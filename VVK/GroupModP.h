//
//  ElgamalPub.h
//  VVK

#import <Foundation/Foundation.h>
#import "Group.h"
#import <openssl/bn.h>

@class Ballot;
@class Scalar;
@class ModPElement;

@interface ModPGroup : Group
{
@private
    BIGNUM* _p;
    BIGNUM* _q;
    BIGNUM* _g;
}

@property (atomic, readonly) BIGNUM* mod;
@property (atomic, readonly) BIGNUM* q;

- (id) initWithParams:(BIGNUM*) mod
            generator:(BIGNUM*) generator;

- (ModPElement*) generator;

- (ModPElement*) elementOfASN1:(NSData*)data;

- (Ballot*) decodeBallotWithName:(NSString*)ballotName
                      ciphertext:(NSData*)ciphertext;

@end

@interface ModPElement : Element
{
@private
    ModPGroup* _group;
    BIGNUM* _value;
}

- (id) initWithValue:(BIGNUM*) value
               group:(ModPGroup*) group;

- (id) initWithModPBytes:(const unsigned char*) data
              length:(long)length
               group:(ModPGroup*) group;

- (id) initWithASN:(ASN1_INTEGER*) asn
             group:(ModPGroup*) group;

- (bool) checkQuadraticResidue;

- (ModPElement*) scaleWithScalar:(Scalar*) scalar;

- (ModPElement*) operationWithElement:(ModPElement*) other;

- (ModPElement*) inverse;

- (bool) equalsWithElement:(ModPElement*) other;

- (NSString*) decode;

- (NSString*) removePadding:(unsigned char*)data
                        len:(int)len;

@end
