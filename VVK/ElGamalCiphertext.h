//
//  ElGamalCiphertext.h
//  VVK

#import <openssl/asn1.h>
#import <openssl/asn1t.h>

typedef struct elgamal_ciphertext_st {
    ASN1_INTEGER* a;
    ASN1_INTEGER* b;
} ELGAMAL_CIPHERTEXT;

typedef struct elgamal_cipher_st {
    X509_ALGOR* alg;
    ELGAMAL_CIPHERTEXT* cipher;
} ELGAMAL_CIPHER;

# define d2i_ELGAMAL_CIPHER_bio(bp,p) ASN1_d2i_bio_of(ELGAMAL_CIPHER,ELGAMAL_CIPHER_new,d2i_ELGAMAL_CIPHER,bp,p)

DECLARE_ASN1_FUNCTIONS(ELGAMAL_CIPHERTEXT)
DECLARE_ASN1_FUNCTIONS(ELGAMAL_CIPHER)
