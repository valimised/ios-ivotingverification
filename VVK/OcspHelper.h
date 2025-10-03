//
//  Ocsp.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/ocsp.h>
#import <openssl/x509.h>

@interface OcspHelper : NSObject
{
    OCSP_BASICRESP* bs;
}

- (id) initWithData:(NSData*)respData;

- (ASN1_GENERALIZEDTIME*) getProducedAt;

- (BOOL) verifyResp:(NSArray*)responderCerts
    requestedCert:(X509*)requestedCert issuerCert:(X509*)issuerCert;

- (int) checkAIAresponder:(X509*)issuer;

@end
