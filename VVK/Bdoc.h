//
//  Bdoc.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/x509.h>

@interface Bdoc : NSObject
{
    NSMutableDictionary* votes;
    X509* cert;
    NSData* signatureValue;
    X509* issuer;
}

@property (atomic, readonly) NSMutableDictionary* votes;
@property (atomic, readonly) X509* cert;
@property (atomic, readonly) NSData* signatureValue;
@property (atomic, readonly) X509* issuer;

- (id) initWithData:(NSData*)data electionId:(NSString*)elid;
- (BOOL) validateBdoc;
@end
