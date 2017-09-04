//
//  Ocsp.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/x509.h>

@interface OcspHelper : NSObject
+ (BOOL)verifyResp:(NSData*)respData responderCertData:(NSArray*)responderCerts
     requestedCert:(X509 *)requestedCert producedAt:(ASN1_GENERALIZEDTIME *)producedAt;
@end
