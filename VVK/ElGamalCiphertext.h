//
//  ElGamalCiphertext.h
//  VVK

#include <openssl/asn1.h>
#include <openssl/asn1t.h>

typedef struct elgamal_modp_ciphertext_st {
    ASN1_INTEGER* uBlind;
    ASN1_INTEGER* vBlindedMsg;
} ELGAMAL_MODP_CIPHERTEXT;

typedef struct elgamal_modp_cipher_st {
    X509_ALGOR* alg;
    ELGAMAL_MODP_CIPHERTEXT* cipher;
} ELGAMAL_MODP_CIPHER;

typedef struct elgamal_ecc_ciphertext_st {
    ASN1_OCTET_STRING* uBlind;
    ASN1_OCTET_STRING* vBlindedMsg;
} ELGAMAL_ECC_CIPHERTEXT;

typedef struct elgamal_ecc_cipher_st {
    X509_ALGOR* alg;
    ELGAMAL_ECC_CIPHERTEXT* cipher;
} ELGAMAL_ECC_CIPHER;

# define d2i_ELGAMAL_MODP_CIPHER_bio(bp,p) ASN1_d2i_bio_of(ELGAMAL_MODP_CIPHER,ELGAMAL_MODP_CIPHER_new,d2i_ELGAMAL_MODP_CIPHER,bp,p)

DECLARE_ASN1_FUNCTIONS(ELGAMAL_MODP_CIPHERTEXT)
DECLARE_ASN1_FUNCTIONS(ELGAMAL_MODP_CIPHER)

# define d2i_ELGAMAL_ECC_CIPHER_bio(bp,p) ASN1_d2i_bio_of(ELGAMAL_ECC_CIPHER,ELGAMAL_ECC_CIPHER_new,d2i_ELGAMAL_ECC_CIPHER,bp,p)

DECLARE_ASN1_FUNCTIONS(ELGAMAL_ECC_CIPHERTEXT)
DECLARE_ASN1_FUNCTIONS(ELGAMAL_ECC_CIPHER)
