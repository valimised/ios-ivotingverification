//
//  PkixNonce.h
//  VVK

#import <openssl/asn1.h>
#import <openssl/asn1t.h>

typedef struct pkix_nonce_st {
    X509_ALGOR *alg;
    ASN1_OCTET_STRING *sig;
} PKIX_NONCE;

# define d2i_PKIX_NONCE_bio(bp,p) ASN1_d2i_bio_of(PKIX_NONCE,PKIX_NONCE_new,d2i_PKIX_NONCE,bp,p)

DECLARE_ASN1_FUNCTIONS(PKIX_NONCE)
