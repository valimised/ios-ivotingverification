//
//  PkixHelper.m
//  VVK

#import "PkixHelper.h"
#import <openssl/bio.h>
#import <openssl/pkcs7.h>
#import <openssl/ts.h>
#import <openssl/pem.h>

@implementation PkixHelper

+ (BOOL) verifyResp:(NSData*)respData collectorRegCert:(NSData*)collectorRegCert
    pkixCert:(NSData*)pkixCert data:(NSData*)data genTime:(ASN1_GENERALIZEDTIME*)genTime
{
    BOOL ret = NO;
    TS_VERIFY_CTX* verify_ctx = NULL;
    PKCS7* token = NULL;
    BIO* inBufData = NULL;
    BIO* inBufPkixCert = NULL;
    X509* pkix = NULL;
    X509_STORE* cert_ctx = NULL;
    const X509_ALGOR* alg = NULL;
    const ASN1_OCTET_STRING* dig = NULL;
    X509_VERIFY_PARAM* vpm = NULL;
    BIO* inBufCollectorCert = NULL;
    X509* collectorRegX509 = NULL;
    EVP_PKEY* collectorPub = NULL;
    TS_TST_INFO* tst_info = NULL;
    EVP_MD_CTX* md_ctx = NULL;
    BIO* inBufReg = BIO_new_mem_buf([respData bytes], (int)[respData length]);

    if (!inBufReg) {
        DLog(@"Couldn't read pkix respData into BIO");
        goto end;
    }

    token = d2i_PKCS7_bio(inBufReg, NULL);

    if (!token) {
        DLog(@"Couldn't read pkix response");
        goto end;
    }

    verify_ctx = TS_VERIFY_CTX_new();
    int f = TS_VFY_VERSION | TS_VFY_SIGNER | TS_VFY_DATA | TS_VFY_SIGNATURE;
    TS_VERIFY_CTX_set_flags(verify_ctx, f);
    inBufData = BIO_new_mem_buf([data bytes], (int)[data length]);

    if (!inBufData) {
        DLog(@"Couldn't read signature value data into BIO");
        goto end;
    }

    TS_VERIFY_CTX_set_data(verify_ctx, inBufData);
    inBufPkixCert = BIO_new_mem_buf([pkixCert bytes], (int)[pkixCert length]);

    if (!inBufPkixCert) {
        DLog(@"Couldn't read pkix cert data into BIO");
        goto end;
    }

    pkix = PEM_read_bio_X509_AUX(inBufPkixCert, NULL, NULL, NULL);

    if (!pkix) {
        DLog(@"Couldn't read pkix cert");
        goto end;
    }

    cert_ctx = X509_STORE_new();

    if (!cert_ctx) {
        DLog(@"Couldn't create X509 store instance");
        goto end;
    }

    X509_STORE_add_cert(cert_ctx, pkix);
    vpm = X509_VERIFY_PARAM_new();

    if (!vpm) {
        DLog(@"Couldn't create X509 verify param instance");
        goto end;
    }

    X509_VERIFY_PARAM_set_flags(vpm, X509_V_FLAG_PARTIAL_CHAIN);
    X509_STORE_set1_param(cert_ctx, vpm);
    STACK_OF(X509)* trustedCerts = sk_X509_new_null();

    if (!trustedCerts) {
        DLog(@"Couldn't create STACK_OF(X509) obj");
        goto end;
    }

    sk_X509_push(trustedCerts, pkix);
    TS_VERIFY_CTX_set_store(verify_ctx, cert_ctx);
    TS_VERIFY_CTS_set_certs(verify_ctx, trustedCerts);

    if (TS_RESP_verify_token(verify_ctx, token) != 1) {
        DLog(@"TS_RESP_verify_token non-successful");
        goto end;
    }

    tst_info = PKCS7_to_TS_TST_INFO(token);

    if (!tst_info) {
        DLog(@"Couldn't get tst info obj from pkcs7 obj");
        goto end;
    }

    inBufCollectorCert = BIO_new_mem_buf([collectorRegCert bytes], (int)[collectorRegCert length]);

    if (!inBufReg) {
        DLog(@"Couldn't read collector reg cert data into BIO");
        goto end;
    }

    collectorRegX509 = PEM_read_bio_X509_AUX(inBufCollectorCert, NULL, NULL, NULL);

    if (!collectorRegX509) {
        DLog(@"Couldn't read collector reg cert");
        goto end;
    }

    collectorPub = X509_get_pubkey(collectorRegX509);

    if (!collectorPub) {
        DLog(@"Couldn't extract public key from collector reg cert");
        goto end;
    }

    // TODO: remove d2i_PKIX_NONCE
    ASN1_INTEGER* nonce = ASN1_INTEGER_dup(TS_TST_INFO_get_nonce(tst_info));
    unsigned char* tmp = nonce->data;
    X509_SIG* xsig = d2i_X509_SIG(NULL, (const unsigned char**) &tmp, nonce->length);
    tmp = NULL;
    X509_SIG_get0(xsig, &alg, &dig);
    md_ctx = EVP_MD_CTX_new();
    const EVP_MD* type = NULL;
    int ii = OBJ_obj2nid(alg->algorithm);
    type = EVP_get_digestbyname(OBJ_nid2sn(ii));

    if (EVP_VerifyInit(md_ctx, type) != 1) {
        DLog(@"Couldn't init digest verify");
        return NO;
    }

    if (EVP_VerifyUpdate(md_ctx, (unsigned char*)[data bytes], [data length]) != 1) {
        DLog(@"Couldn't add digest input data to context");
        return NO;
    }

    if (EVP_VerifyFinal(md_ctx, dig->data, dig->length, collectorPub) <= 0) {
        DLog(@"Nonce verification non-successful");
        return NO;
    }

    genTime = (ASN1_GENERALIZEDTIME*) TS_TST_INFO_get_time(tst_info);
    ret =  YES;
end:
    BIO_free(inBufReg);
    PKCS7_free(token);
    TS_VERIFY_CTX_free(verify_ctx);
    BIO_free(inBufPkixCert);
    BIO_free(inBufCollectorCert);
    X509_free(collectorRegX509);
    EVP_PKEY_free(collectorPub);
    EVP_MD_CTX_destroy(md_ctx);
    return ret;
}
@end
