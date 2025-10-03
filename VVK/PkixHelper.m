//
//  PkixHelper.m
//  VVK

#import "PkixHelper.h"
#import <openssl/bio.h>
#import <openssl/pkcs7.h>
#import <openssl/ts.h>
#import <openssl/pem.h>

@implementation PkixHelper


- (id) initWithData:(NSData*)respData
{
    self = [super init];
    if (!self) return nil;

    token = NULL;
    tst_info = NULL;

    BIO* inBufReg = BIO_new_mem_buf([respData bytes], (int)[respData length]);

    if (!inBufReg) {
        DLog(@"Couldn't read pkix respData into BIO");
        return nil;
    }

    token = d2i_PKCS7_bio(inBufReg, NULL);

    BIO_free(inBufReg);

    if (!token) {
        DLog(@"Couldn't read pkix response");
        return nil;
    }

    tst_info = PKCS7_to_TS_TST_INFO(token);

    if (!tst_info) {
        DLog(@"Couldn't get tst info obj from pkcs7 obj");
        return nil;
    }

    return self;

}


- (ASN1_GENERALIZEDTIME*) getTime
{
    return ASN1_GENERALIZEDTIME_dup(TS_TST_INFO_get_time(tst_info));
}


- (BOOL) verifyResp:(NSData*)collectorRegCert
    pkixCert:(NSData*)pkixCert data:(NSData*)data
{
    BOOL ret = NO;
    TS_VERIFY_CTX* verify_ctx = NULL;
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
    EVP_MD_CTX* md_ctx = NULL;


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

    inBufCollectorCert = BIO_new_mem_buf([collectorRegCert bytes], (int)[collectorRegCert length]);

    if (!inBufCollectorCert) {
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

    ret =  YES;
end:
    TS_VERIFY_CTX_free(verify_ctx);
    BIO_free(inBufPkixCert);
    BIO_free(inBufCollectorCert);
    X509_free(collectorRegX509);
    EVP_PKEY_free(collectorPub);
    EVP_MD_CTX_destroy(md_ctx);
    return ret;
}


- (BOOL) compareWithOCSP:(OcspHelper*)ocsp maxdiff:(int)maxdiff
{

    BOOL ret = NO;

    ASN1_GENERALIZEDTIME *pkix_gen_time = NULL;
    ASN1_GENERALIZEDTIME *ocsp_produced_at = NULL;

    int pday = 0;
    int psec = 0;

    if (!ocsp) {
        goto error;
    }

    ocsp_produced_at = [ocsp getProducedAt];
    if (ocsp_produced_at == NULL) {
        goto error;
    }

    pkix_gen_time = [self getTime];
    if (pkix_gen_time == NULL) {
        goto error;
    }

    if (!ASN1_TIME_diff(&pday, &psec, pkix_gen_time, ocsp_produced_at)) {
        goto error;
    }

    if (pday != 0) {
        goto error;
    }

    if (psec < 0) {
        goto error;
    }

    if (psec > maxdiff) {
        goto error;
    }

    ret = YES;

error:

    ASN1_GENERALIZEDTIME_free(ocsp_produced_at);
    ASN1_GENERALIZEDTIME_free(pkix_gen_time);

    return ret;
}


- (void) dealloc
{
    PKCS7_free(token);
    TS_TST_INFO_free(tst_info);
}

@end
