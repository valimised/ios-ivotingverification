//
//  Scalar.h
//  VVK
//
//  Created by Sven Heiberg on 29.11.2024.
//

#import <Foundation/Foundation.h>
#import <openssl/bn.h>

@class Group;

@interface Scalar : NSObject
{
@private
    BIGNUM* _value;
    Group* _group;
}

@property (atomic, readonly) BIGNUM* value;

- (id) initWithValue:(BIGNUM*) value
               group:(Group*) group;

- (id) initWithBytes:(NSData*) value_bytes
               group:(Group*) group;

@end
