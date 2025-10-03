//
//  ElgamalPub.h
//  VVK

#import <Foundation/Foundation.h>
#import "Group.h"
#import <openssl/ec.h>

@class Ballot;
@class Scalar;
@class ECCElement;

@interface ECCGroup : Group
{
@private
    EC_GROUP* _ecg;
}

@property (atomic, readonly) EC_GROUP* ecg;

- (id) initWithName:(NSString*) curve_name;

- (ECCElement*) generator;

- (ECCElement*) elementOfASN1:(NSData*)data;

- (Ballot*) decodeBallotWithName:(NSString*)ballotName
                      ciphertext:(NSData*)ciphertext;

@end

@interface ECCElement : Element
{
@private
    ECCGroup* _group;
    EC_POINT* _value;
}

- (id) initWithValue:(const EC_POINT*) value
               group:(ECCGroup*) group;

- (id) initWithECCBytes:(const unsigned char*) data
              length:(long)length
               group:(ECCGroup*) group;

- (id) initWithASN:(const ASN1_OCTET_STRING*) asn
             group:(ECCGroup*) group;

- (ECCElement*) scaleWithScalar:(Scalar*) scalar;

- (ECCElement*) operationWithElement:(ECCElement*) other;

- (ECCElement*) inverse;

- (bool) equalsWithElement:(ECCElement*) other;

- (NSString*) decode;

@end
