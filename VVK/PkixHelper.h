//
//  PkixHelper.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/ossl_typ.h>
#import <openssl/pkcs7.h>
#import <openssl/ts.h>
#import "OcspHelper.h"

@interface PkixHelper : NSObject
{
    PKCS7* token;
    TS_TST_INFO* tst_info;
}

- (id) initWithData:(NSData*)respData;

- (BOOL) verifyResp:(NSData*)collectorRegCert pkixCert:(NSData*)pkixCert data:(NSData*)data;

- (ASN1_GENERALIZEDTIME*) getTime;

- (BOOL) compareWithOCSP:(OcspHelper*)ocsp maxdiff:(int)maxdiff;

@end
