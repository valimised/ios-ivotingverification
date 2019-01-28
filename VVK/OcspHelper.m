//
//  Ocsp.m
//  VVK

#import "OcspHelper.h"
#import <openssl/ocsp.h>
#import <openssl/pem.h>
#import <openssl/err.h>

@interface OcspHelper()
+(int)checkAIAresponder:(OCSP_BASICRESP*)resp issuer:(X509*)issuer;
@end

@implementation OcspHelper

+ (BOOL)verifyResp:(NSData *)respData responderCertData:(NSArray *)responderCerts
     requestedCert:(X509 *)requestedCert issuerCert:(X509 *)issuerCert
        producedAt:(ASN1_GENERALIZEDTIME *)producedAt
{
    BOOL ret = NO;
    OCSP_RESPONSE* resp = NULL;
    X509* cert = NULL;
    STACK_OF(X509)* trustedCerts = NULL;
    OCSP_BASICRESP* bs = NULL;
    OCSP_CERTID* reqCertId  = NULL;
    BIO* certBio = NULL;
    
    // Read and init ocsp response
    BIO* respBio = BIO_new_mem_buf([respData bytes], (int)[respData length]);
    if (respBio == NULL) {
        DLog(@"Couldn't read respData into BIO");
        goto end;
    }
    resp = d2i_OCSP_RESPONSE_bio(respBio, NULL);
    BIO_free(respBio);
    if (resp == NULL) {
        DLog(@"Couldn't parse OCSP response");
        goto end;
    }
    
    trustedCerts = sk_X509_new_null();
    if (trustedCerts == NULL) {
        DLog(@"Couldn't create STACK_OF(X509) obj");
        goto end;
    }

    // read and init ocsp responder certs
    for (NSString* certStr in responderCerts) {
        NSData* certData = [certStr dataUsingEncoding:NSUTF8StringEncoding];
        certBio = BIO_new_mem_buf([certData bytes], (int)[certData length]);
        if (certBio == NULL) {
            DLog(@"Couldn't read responderCertData into BIO");
            goto end;
        }
        cert = PEM_read_bio_X509_AUX(certBio, NULL, NULL, NULL);
        BIO_free(certBio);
        if (cert == NULL) {
            DLog(@"Couldn't load responder X509 cert");
            goto end;
        }
        // trust ocsp responder cert
        sk_X509_push(trustedCerts, cert);
    }

    int i;
    
    i = OCSP_response_status(resp);
    
    if (i != OCSP_RESPONSE_STATUS_SUCCESSFUL) {
        DLog(@"OCSP response not successful: %s", OCSP_response_status_str(i));
        goto end;
    }
    
    bs = OCSP_response_get1_basic(resp);
    if (!bs) {
        DLog(@"Couldn't init Basic OCSP response");
        goto end;
    }

    i = OCSP_basic_verify(bs, trustedCerts, NULL, OCSP_TRUSTOTHER | OCSP_NOINTERN);
    if (i <= 0) {
        i = [self checkAIAresponder:bs issuer:issuerCert];
    }

    if (i <= 0) {
        DLog(@"OCSP basic response verification failed");
        goto end;
    }

    // create incorrect certId (using subject public key instead of issuer key) on purpose.
    // will fix manually after object creation.
    reqCertId = OCSP_cert_id_new(EVP_sha1() ,
                                              X509_get_issuer_name(requestedCert),
                                              X509_get0_pubkey_bitstr(requestedCert),
                                              X509_get_serialNumber(requestedCert));
    
    int loc = X509_get_ext_by_NID(requestedCert, NID_authority_key_identifier, -1);
    if (loc < 0) {
        DLog(@"Requested cert does not contain auth key identifier extension");
        goto end;
    }
    X509_EXTENSION* ex = X509_get_ext(requestedCert, loc);
    AUTHORITY_KEYID* authKeyId = (AUTHORITY_KEYID*) X509V3_EXT_d2i(ex);
    // set the correct issuer key hash here.
    reqCertId->issuerKeyHash = authKeyId->keyid;
    
    int* status = NULL;
    
    if (!OCSP_resp_find_status(bs, reqCertId, status, NULL, NULL, NULL, NULL)) {
        DLog(@"OCSP response does not contain status response of the requested certificate");
        goto end;
    }
    
    if (status != V_OCSP_CERTSTATUS_GOOD) {
        DLog(@"certificate status is not good");
        goto end;
    }
    
    ret = YES;
    producedAt = bs->tbsResponseData->producedAt;
    
end:
    OCSP_RESPONSE_free(resp);
    //X509_free(cert);
    sk_X509_pop_free(trustedCerts, X509_free);
    OCSP_BASICRESP_free(bs);
    OCSP_CERTID_free(reqCertId);
    
    return ret;
}

+(int)checkAIAresponder:(OCSP_BASICRESP *)resp issuer:(X509 *)issuer
{
    int ret = 0;
    STACK_OF(X509)* trustedCerts = sk_X509_new_null();
    if (trustedCerts == NULL) {
        DLog(@"Couldn't create STACK_OF(X509) obj");
        goto end;
    }
    
    for (int i = 0; i < sk_X509_num(resp->certs); i++) {
        X509 *responderCert = sk_X509_value(resp->certs, i);
        // is signed by same issuer as the cert whose ocsp we are checking
        int retval = X509_check_issued(issuer, responderCert);
        if (retval == X509_V_OK) {
            // and has proper signature of the responder
            sk_X509_push(trustedCerts, responderCert);
            int res = OCSP_basic_verify(resp, trustedCerts, NULL, OCSP_TRUSTOTHER | OCSP_NOINTERN);
            sk_X509_pop(trustedCerts);
            if (res > 0) {
                // and responder has proper key extension
                X509_check_purpose(responderCert, -1, 0);
                if ((responderCert->ex_flags & EXFLAG_XKUSAGE) && (responderCert->ex_xkusage & XKU_OCSP_SIGN)) {
                    ret = 1;
                    break;
                }
            }
        }
    }
end:
    sk_X509_free(trustedCerts);
    return ret;
}

@end
