//
//  Crypto.m
//  VVK
//
//  Created by Eigen Lenk on 2/4/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "Crypto.h"
#import "AppDelegate.h"

#import <openssl/pem.h>

@implementation Crypto

static RSA * publicKeyRSA = NULL;

+ (NSString *)stringToHex:(NSString *)string
{
    const char * utf8 = [string UTF8String];
    NSMutableString * hex = [NSMutableString string];
    while (*utf8) [hex appendFormat:@"%02X", ((unsigned char)*utf8++) & 0x00FF];
    return [NSString stringWithFormat:@"%@", hex];
}

+ (NSString *)hexToString:(NSString *)hexString
{
    NSMutableString * newString = [[NSMutableString alloc] init];
    
    int i = 0;
    while (i < [hexString length])
    {
        NSString * hexChar = [hexString substringWithRange: NSMakeRange(i, 2)];
        int value = 0;
        sscanf([hexChar cStringUsingEncoding:NSASCIIStringEncoding], "%x", &value);
        [newString appendFormat:@"%c", (char)value];
        i+=2;
    }
    
    return newString;
}

static int MGF1(unsigned char *mask, long len, const unsigned char *seed, long seedlen) {
    return PKCS1_MGF1(mask, len, seed, seedlen, EVP_sha1());
}

int RSA_padding_add_PKCS1_OAEPa(unsigned char *to, int tlen,
                                const unsigned char *from, int flen,
                                const unsigned char *param, int plen,
                                unsigned char *inseed /* SHA_DIGEST_LENGTH*/)
{
    int i, emlen = tlen - 1;
    unsigned char *db, *seed;
    unsigned char *dbmask, seedmask[SHA_DIGEST_LENGTH];
    
    if (flen > emlen - 2 * SHA_DIGEST_LENGTH - 1)
    {
        /*RSAerr(RSA_F_RSA_PADDING_ADD_PKCS1_OAEP,
               RSA_R_DATA_TOO_LARGE_FOR_KEY_SIZE);*/
        return 0;
    }
    
    if (emlen < 2 * SHA_DIGEST_LENGTH + 1)
    {
        // RSAerr(RSA_F_RSA_PADDING_ADD_PKCS1_OAEP, RSA_R_KEY_SIZE_TOO_SMALL);
        return 0;
    }
    
    to[0] = 0;
    seed = to + 1;
    db = to + SHA_DIGEST_LENGTH + 1;
    
    if (!EVP_Digest((void *)param, plen, db, NULL, EVP_sha1(), NULL))
        return 0;
    memset(db + SHA_DIGEST_LENGTH, 0,
           emlen - flen - 2 * SHA_DIGEST_LENGTH - 1);
    db[emlen - flen - SHA_DIGEST_LENGTH - 1] = 0x01;
    memcpy(db + emlen - flen - SHA_DIGEST_LENGTH, from, (unsigned int) flen);
    memcpy(seed, inseed, SHA_DIGEST_LENGTH);
    
    dbmask = (unsigned char*)OPENSSL_malloc(emlen - SHA_DIGEST_LENGTH);
    
    if (dbmask == NULL)
    {
        // RSAerr(RSA_F_RSA_PADDING_ADD_PKCS1_OAEP, ERR_R_MALLOC_FAILURE);
        return 0;
    }
    
    if (MGF1(dbmask, emlen - SHA_DIGEST_LENGTH, seed, SHA_DIGEST_LENGTH) < 0)
        return 0;
    for (i = 0; i < emlen - SHA_DIGEST_LENGTH; i++)
        db[i] ^= dbmask[i];
    
    if (MGF1(seedmask, SHA_DIGEST_LENGTH, db, emlen - SHA_DIGEST_LENGTH) < 0)
        return 0;
    for (i = 0; i < SHA_DIGEST_LENGTH; i++)
        seed[i] ^= seedmask[i];
    
    OPENSSL_free(dbmask);
    
    return 1;
}

static int RSA_OAEP_public_encrypt(int flen,
                                   const unsigned char *from,
                                   unsigned char *to,
                                   RSA *rsa,
                                   unsigned char *oaep_seed)
{
    BIGNUM *f,*ret;
    int i,j,k,num=0,r= -1;
    unsigned char *buf=NULL;
    BN_CTX *ctx=NULL;
    
    if (BN_num_bits(rsa->n) > OPENSSL_RSA_MAX_MODULUS_BITS) {
        // RSAerr(RSA_F_RSA_EAY_PUBLIC_ENCRYPT, RSA_R_MODULUS_TOO_LARGE);
        return -1;
    }
    
    if (BN_ucmp(rsa->n, rsa->e) <= 0) {
        // RSAerr(RSA_F_RSA_EAY_PUBLIC_ENCRYPT, RSA_R_BAD_E_VALUE);
        return -1;
    }
    
    /* for large moduli, enforce exponent limit */
    if (BN_num_bits(rsa->n) > OPENSSL_RSA_SMALL_MODULUS_BITS) {
        if (BN_num_bits(rsa->e) > OPENSSL_RSA_MAX_PUBEXP_BITS) {
            // RSAerr(RSA_F_RSA_EAY_PUBLIC_ENCRYPT, RSA_R_BAD_E_VALUE);
            return -1;
        }
    }
    
    if ((ctx=BN_CTX_new()) == NULL) goto err;
    BN_CTX_start(ctx);
    f = BN_CTX_get(ctx);
    ret = BN_CTX_get(ctx);
    num=BN_num_bytes(rsa->n);
    buf = (unsigned char *)OPENSSL_malloc(num);
    
    if (!f || !ret || !buf) {
        // RSAerr(RSA_F_RSA_EAY_PUBLIC_ENCRYPT,ERR_R_MALLOC_FAILURE);
        goto err;
    }
    
    i=RSA_padding_add_PKCS1_OAEPa(buf,num,from,flen,NULL,0, oaep_seed);
    
    if (i <= 0) goto err;
    
    if (BN_bin2bn(buf,num,f) == NULL) goto err;
    
    if (BN_ucmp(f, rsa->n) >= 0) {
        /* usually the padding functions would catch this */
        // RSAerr(RSA_F_RSA_EAY_PUBLIC_ENCRYPT,RSA_R_DATA_TOO_LARGE_FOR_MODULUS);
        goto err;
    }
    
    if (rsa->flags & RSA_FLAG_CACHE_PUBLIC) {
        if (!BN_MONT_CTX_set_locked(&rsa->_method_mod_n, CRYPTO_LOCK_RSA, rsa->n, ctx)) {
            goto err;
        }
    }
    
    if (!rsa->meth->bn_mod_exp(ret,f,rsa->e,rsa->n,ctx, rsa->_method_mod_n)) {
	    goto err;
	}
    
    /* put in leading 0 bytes if the number is less than the
     * length of the modulus */
    j=BN_num_bytes(ret);
    i=BN_bn2bin(ret,&(to[num-j]));
    for (k=0; k<(num-i); k++) {
        to[k]=0;
    }
    
    r=num;
err:
    if (ctx != NULL) {
        BN_CTX_end(ctx);
        BN_CTX_free(ctx);
    }
    if (buf != NULL) {
        OPENSSL_cleanse(buf,num);
        OPENSSL_free(buf);
    }
    return(r);
}

+ (NSString *)encryptVote:(in NSString *)vote withSeed:(in NSString *)seed
{
    int outlen = 0;
    char * outbuf = NULL;

    NSString * decodedSeed = [Crypto hexToString:seed];
    
    // Prepare output buffer
    outbuf = (char *)malloc(RSA_size(publicKeyRSA));
    
    // Encrypt
    outlen = RSA_OAEP_public_encrypt((int)[vote length],
                                     (unsigned char*)[vote cStringUsingEncoding:NSUTF8StringEncoding],
                                     (unsigned char *)outbuf,
                                     publicKeyRSA,
                                     (unsigned char*)[decodedSeed cStringUsingEncoding:NSMacOSRomanStringEncoding]);

    decodedSeed = nil;
    
    if (outlen <= 0)
    {
        free(outbuf);
        return nil;
    }
    
    NSMutableString * hex = [NSMutableString string];
    
    for (unsigned int i = 0; i < outlen; ++i)
        [hex appendFormat:@"%02X", ((unsigned char)outbuf[i]) & 0x00FF];

    free(outbuf);
    
    return hex;
}

+ (BOOL)initPublicKey:(in NSString *)publicKey
{
    const char * p = (char *)[publicKey UTF8String];
    NSUInteger byteCount = [publicKey lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    BIO * bufio = BIO_new_mem_buf((void*)p, byteCount);
    
    publicKeyRSA = PEM_read_bio_RSA_PUBKEY(bufio, 0, 0, 0);
    
    if (!publicKeyRSA)
    {
        DLog(@"error");
        
        return NO;
    }
    
    return YES;
}

+ (BOOL)clearPublicKey
{
    if (!publicKeyRSA) {
        return NO;
    }
    
    RSA_free(publicKeyRSA);
    
    publicKeyRSA = NULL;
    
    return YES;
}

@end
