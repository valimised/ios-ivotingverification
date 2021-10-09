//
//  Ocsp.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/x509.h>

@interface OcspHelper : NSObject
+ (BOOL) verifyResp:(NSData*)respData responderCertData:(NSArray*)responderCerts
    requestedCert:(X509*)requestedCert issuerCert:(X509*)issuerCert
    producedAt:(ASN1_GENERALIZEDTIME*)producedAt;
@end
