//
//  ElgamalPub.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/bn.h>

@interface ElgamalPub : NSObject
{
    BIGNUM* p;
    BIGNUM* q;
    BIGNUM* g;
    BIGNUM* y;
    NSString* elId;
}

@property (atomic, readonly) BIGNUM* p;
@property (atomic, readonly) BIGNUM* q;
@property (atomic, readonly) BIGNUM* g;
@property (atomic, readonly) BIGNUM* y;
@property (atomic, readonly) NSString* elId;

- (id) initWithPemString:(NSString*)pemStr;

@end
