//
//  PkixHelper.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/ossl_typ.h>

@interface PkixHelper : NSObject
+ (BOOL)verifyResp:(NSData*)respData collectorRegCert:(NSData *)collectorRegCert
     pkixCert:(NSData *)pkixCert data:(NSData *)data genTime:(ASN1_GENERALIZEDTIME *)genTime;
@end
