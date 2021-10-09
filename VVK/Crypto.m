//
//  Crypto.m
//  VVK

#import "Crypto.h"
#import "AppDelegate.h"
#import "ElgamalPub.h"

@interface Crypto()

+ removePadding:(unsigned char*)paddedData len:(int)len publen:(int)publen;

@end

@implementation Crypto

+ (NSString*) stringToHex:(NSString*)string
{
    const char* utf8 = [string UTF8String];
    NSMutableString* hex = [NSMutableString string];

    while (*utf8) {
        [hex appendFormat:@"%02X", ((unsigned char)*utf8++) & 0x00FF];
    }

    return [NSString stringWithFormat:@"%@", hex];
}

+ (NSData*) hexToString:(NSString*)hexString
{
    NSMutableData* decodedData = [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0', '\0', '\0'};

    for (int i = 0; i < ([hexString length] / 2); i++) {
        byte_chars[0] = [hexString characterAtIndex:i * 2];
        byte_chars[1] = [hexString characterAtIndex:i * 2 + 1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [decodedData appendBytes:&whole_byte length:1];
    }

    return decodedData;
}


+ (NSString*) removePadding:(unsigned char*)data len:(int)len publen:(int)publen
{
    if (len < 2) {
        DLog(@"Source message can not contain padding");
        return nil;
    }

    // As the plaintext byte array is obtained from BIGNUM, leading 0 is omitted
    if (len + 1 != publen / 8) {
        DLog(@"Incorrect plaintext length");
        return nil;
    }

    if (data[0] != 0x01) {
        DLog(@"Incorrect padding head");
        return nil;
    }

    data++;
    NSString* tmp = nil;

    for (int i = 1; i < len; i++) {
        switch (data[0]) {
        case 0x00:
            data++;
            tmp = [[NSString alloc] initWithBytes:data length:len - i encoding:NSUTF8StringEncoding];
            return tmp;

        case 0xff:
            data++;
            continue;

        default:
            DLog(@"Incorrect padding byte");
            return nil;
        }
    }

    DLog(@"Incorrect padding");
    return nil;
}

static unsigned char* BN_to_binary(BIGNUM* b, unsigned int* len)
{
    unsigned char* ret;
    *len = BN_num_bytes(b);

    if (!(ret = (unsigned char*)malloc(*len + 1))) {
        return NULL;
    }

    memset(ret, 0, *len + 1);  // To keep NSString initWithBytes from failing
    BN_bn2bin(b, ret);
    return ret;
}

+ (NSString*) decryptVote:(unsigned char*)vote voteLen:(int)len withRnd:(NSData*)rnd key:
    (ElgamalPub*)pub
{
    // DLog(@"Vote: %@", vote);
    // DLog(@"Seed: %@", seed);
    BIGNUM* voteBN = NULL;
    BIGNUM* rndBN = NULL;
    BN_CTX* ctx = NULL;
    BIGNUM* factor = NULL;
    BIGNUM* factorInverse = NULL;
    BIGNUM* s = NULL;
    BIGNUM* m = NULL;
    BIGNUM* tmp = NULL;
    NSString* ret = NULL;
    unsigned char* bin = NULL;
    unsigned int pLen = 0;
    voteBN = BN_bin2bn(vote, len, NULL);
    rndBN = BN_bin2bn([rnd bytes], (int)[rnd length], NULL);
    ctx = BN_CTX_new();
    factor = BN_new();
    factorInverse = BN_new();
    s = BN_new();
    tmp = BN_new();

    if (ctx == NULL || factor == NULL || factorInverse == NULL || s == NULL || voteBN == NULL ||
            rndBN == NULL || tmp == NULL) {
        goto end;
    }

    BN_mod_exp(factor, pub.y, rndBN, pub.p, ctx);
    BN_mod_inverse(factorInverse, factor, pub.p, ctx);
    BN_mod_mul(s, factorInverse, voteBN, pub.p, ctx);
    BN_mod_exp(tmp, s, pub.q, pub.p, ctx);

    if (!BN_is_one(tmp)) {
        DLog(@"plaintext is not quadratic residue");
        goto end;
    }

    if (BN_ucmp(s, pub.q) == 1) {
        m = BN_new();
        BN_sub(m, pub.p, s);
    }
    else {
        m = s;
        s = NULL;
    }

    bin = BN_to_binary(m, &pLen);

    if (bin == NULL) {
        goto end;
    }

    ret = [Crypto removePadding:bin len:pLen publen:BN_num_bits(pub.p)];
end:
    BN_clear_free(voteBN);
    BN_clear_free(rndBN);
    BN_CTX_free(ctx);
    BN_clear_free(factor);
    BN_clear_free(factorInverse);
    BN_clear_free(s);
    BN_clear_free(m);
    BN_clear_free(tmp);
    free(bin);
    return ret;
}
@end
