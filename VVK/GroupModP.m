//
//  ElgamalPub.m
//  VVK

#import "GroupModP.h"
#import "Ballot.h"
#import "Scalar.h"
#import <openssl/asn1.h>
#import <openssl/x509.h>
#import "ElGamalCiphertext.h"

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

@implementation ModPGroup

@synthesize mod=_p;
@synthesize q=_q;

- (id) initWithParams:(BIGNUM*) mod
            generator:(BIGNUM*) generator
{
    self = [super init];

    ModPGroup *retval = nil;
    BIGNUM *tmp_mod = NULL;
    BIGNUM *tmp_generator = NULL;
    BIGNUM *tmp_q = NULL;

    if ((mod == NULL) || (generator == NULL)) {
        goto error;
    }

    _q = BN_new();
    if (_q == NULL) {
        goto error;
    }

    tmp_mod = BN_dup(mod);
    tmp_generator = BN_dup(generator);
    tmp_q = BN_new();

    if ((tmp_mod == NULL) || (tmp_generator == NULL) || (tmp_q == NULL)) {
        goto error;
    }

    if (!BN_sub(tmp_q, mod, BN_value_one())) goto error;
    if (!BN_rshift1(_q, tmp_q)) goto error;

    _p = tmp_mod;
    tmp_mod = NULL;
    _g = tmp_generator;
    tmp_generator = NULL;
    retval = self;

error:

    BN_clear_free(tmp_mod);
    BN_clear_free(tmp_generator);
    BN_clear_free(tmp_q);
    return retval;
}

- (ModPElement*) generator
{
    return [[ModPElement alloc] initWithValue:_g group:self];
}

- (ModPElement*) elementOfASN1:(NSData*)data
{
    ModPElement *ret = nil;

    const unsigned char* derBytes = [data bytes];
    long derLength = [data length];

    ASN1_INTEGER *asn1Integer = d2i_ASN1_INTEGER(NULL, &derBytes, derLength);

    if (asn1Integer) {
        ret = [[ModPElement alloc] initWithASN:asn1Integer group:self];
    }

    ASN1_INTEGER_free(asn1Integer);
    return ret;
}


- (Ballot*) decodeBallotWithName:(NSString*)ballotName
                      ciphertext:(NSData *)ciphertext
{
    Ballot *ret = nil;

    BIO* cBio = BIO_new_mem_buf([ciphertext bytes], (int)[ciphertext length]);
    ELGAMAL_MODP_CIPHER *vote = d2i_ELGAMAL_MODP_CIPHER_bio(cBio, NULL);
    if (vote == NULL) {
        return nil;
    }

    if (vote->alg == NULL) {
        return nil;
    }

    if (vote->alg->parameter != NULL) {
        return nil;
    }

    ASN1_OBJECT *oid = OBJ_txt2obj("1.3.6.1.4.1.3029.2.1", 1);
    if (oid == NULL) {
        return nil;
    }

    int cmp = OBJ_cmp(oid, vote->alg->algorithm);
    ASN1_OBJECT_free(oid);

    if (cmp != 0) {
        return nil;
    }

    Element *uBlind = [[ModPElement alloc] initWithASN:vote->cipher->uBlind
                                                 group:self];
    Element *vBlindedMsg = [[ModPElement alloc] initWithASN:vote->cipher->vBlindedMsg
                                                      group:self];
    ret = [[Ballot alloc] initWithName:ballotName uBlind:uBlind vBlindedMsg:vBlindedMsg];
    return ret;
}


- (void) dealloc
{
    DLog(@"ModPGroup dealloc");
    BN_clear_free(_p);
    BN_clear_free(_g);
    BN_clear_free(_q);
}

@end


@implementation ModPElement

- (id) decodeFromBytes:(const unsigned char*) data
                length:(long) length
                 group:(ModPGroup*) group
{
    if ((data == NULL) || (group == nil)) {
        return nil;
    }

    _value = BN_bin2bn(data, (int)length, NULL);
    if (_value == NULL) {
        return nil;
    }

    _group = group;
    return self;
}

- (id) initWithValue:(BIGNUM*) value
               group:(ModPGroup*) group
{
    self = [super init];

    if ((value == NULL) || (group == nil)) {
        return nil;
    }

    _value = BN_dup(value);
    if (_value == NULL) {
        return nil;
    }

    _group = group;
    return self;
}

- (id) initWithModPBytes:(const unsigned char*) data
              length:(long)length
               group:(ModPGroup*) group
{
    self = [super init];
    return [self decodeFromBytes:data length:length group:group];
}

- (id) initWithASN:(ASN1_INTEGER *) asn
             group:(ModPGroup *) group
{
    self = [super init];
    if (asn == NULL) {
        return nil;
    }
    return [self decodeFromBytes:asn->data length:asn->length group:group];
}

- (ModPElement*) scaleWithScalar:(Scalar*) scalar
{
    ModPElement *ret = nil;
    BIGNUM *tmp = BN_new();
    BN_CTX *ctx = BN_CTX_new();

    if ((scalar == nil) || (tmp == NULL) || (ctx == NULL)) {
        goto error;
    }

    if (!BN_mod_exp(tmp, _value, scalar.value, _group.mod, ctx)) {
        goto error;
    }

    ret = [[ModPElement alloc] initWithValue:tmp group:_group];

error:

    BN_clear_free(tmp);
    BN_CTX_free(ctx);

    return ret;
}

- (ModPElement*) operationWithElement:(ModPElement*) other
{
    ModPElement *ret = nil;
    BIGNUM *tmp = BN_new();
    BN_CTX *ctx = BN_CTX_new();

    if ((other == nil) || (tmp == NULL) || (ctx == NULL)) {
        goto error;
    }

    if (!BN_mod_mul(tmp, _value, other->_value, _group.mod, ctx)) {
        goto error;
    }

    ret = [[ModPElement alloc] initWithValue:tmp group:_group];

error:

    BN_clear_free(tmp);
    BN_CTX_free(ctx);

    return ret;
}

- (ModPElement*) inverse
{
    ModPElement *ret = nil;
    BIGNUM *tmp = BN_new();
    BN_CTX *ctx = BN_CTX_new();

    if ((tmp == NULL) || (ctx == NULL)) {
        goto error;
    }

    if (!BN_mod_inverse(tmp, _value, _group.mod, ctx)) {
        goto error;
    }

    ret = [[ModPElement alloc] initWithValue:tmp group:_group];

error:

    BN_clear_free(tmp);
    BN_CTX_free(ctx);

    return ret;
}


- (bool) equalsWithElement:(ModPElement*) other
{
    if (other == nil)  {
        return false;
    }

    if (BN_cmp(_value, other->_value) != 0) {
        return false;
    }
    return true;
}


- (bool) checkQuadraticResidue
{
    bool ret = false;
    BN_CTX* ctx = BN_CTX_new();
    BIGNUM* tmp = BN_new();

    if ((ctx == NULL) || (tmp == NULL)) {
        goto end;
    }

    if (!BN_mod_exp(tmp, _value, _group.q, _group.mod, ctx)) {
        goto end;
    }

    if (BN_is_one(tmp)) {
        ret = true;
    }

end:

    BN_CTX_free(ctx);
    BN_clear_free(tmp);
    return ret;
}


- (NSString*) decode {

    BIGNUM* m = NULL;
    NSString* ret = nil;
    unsigned char* bin = NULL;
    unsigned int pLen = 0;

    if (![self checkQuadraticResidue]) {
        DLog(@"plaintext is not quadratic residue");
        goto end;
    }

    if (BN_ucmp(_value, _group.q) == 1) {
        m = BN_new();
        BN_sub(m, _group.mod, _value);
    }
    else {
        m = BN_dup(_value);
    }

    bin = BN_to_binary(m, &pLen);

    if (bin == NULL) {
        goto end;
    }

    ret = [self removePadding:bin len:pLen];

end:

    OPENSSL_free(bin);
    BN_clear_free(m);

    return ret;
}

- (NSString*) removePadding:(unsigned char*)data len:(int)len
{
    int ii = 0;
    if (len < 2) {
        DLog(@"Source message can not contain padding");
        return nil;
    }

    // As the plaintext byte array is obtained from BIGNUM, leading 0 is omitted
    if (len + 1 != BN_num_bits(_group.mod) / 8) {
        DLog(@"Incorrect plaintext length");
        return nil;
    }

    if (data[0] != 0x01) {
        DLog(@"Incorrect padding head");
        return nil;
    }

    data++;
    NSString* tmp = nil;

    for (ii = 1; ii < len; ii++) {
        switch (data[0]) {
            case 0x00:
                data++;
                tmp = [[NSString alloc] initWithBytes:data length:len - (ii + 1) encoding:NSUTF8StringEncoding];
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

- (void) dealloc
{
    DLog(@"ModPElement dealloc");
    _group = nil;
    BN_clear_free(_value);
}

@end
