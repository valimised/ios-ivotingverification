//
//  ElgamalPub.m
//  VVK

#import "GroupECC.h"
#import "Ballot.h"
#import "Scalar.h"
#import <openssl/asn1.h>
#import <openssl/x509.h>
#import "ElGamalCiphertext.h"

@implementation ECCGroup

@synthesize ecg=_ecg;

- (id) initWithName:(NSString*) curve_name
{
    self = [super init];
    const char* cname = [curve_name UTF8String];
    int nid = EC_curve_nist2nid(cname);
    _ecg = EC_GROUP_new_by_curve_name(nid);
    return self;
}

- (ECCElement*) generator
{
    return [[ECCElement alloc] initWithValue:EC_GROUP_get0_generator(_ecg) group:self];
}

- (ECCElement*) elementOfASN1:(NSData*)data
{
    ECCElement *ret = nil;

    const unsigned char* derBytes = [data bytes];
    long derLength = [data length];

    ASN1_OCTET_STRING *asn1OctetString = d2i_ASN1_OCTET_STRING(NULL, &derBytes, derLength);

    if (asn1OctetString) {
        ret = [[ECCElement alloc] initWithASN:asn1OctetString group:self];
    }

    ASN1_OCTET_STRING_free(asn1OctetString);
    return ret;
}

- (Ballot*) decodeBallotWithName:(NSString*)ballotName
                      ciphertext:(NSData *)ciphertext
{
    Ballot *ret = nil;

    BIO* cBio = BIO_new_mem_buf([ciphertext bytes], (int)[ciphertext length]);
    ELGAMAL_ECC_CIPHER *vote = d2i_ELGAMAL_ECC_CIPHER_bio(cBio, NULL);
    if (vote == NULL) {
        return nil;
    }

    if (vote->alg == NULL) {
        return nil;
    }

    if (vote->alg->parameter != NULL) {
        return nil;
    }

    ASN1_OBJECT *oid = OBJ_txt2obj("1.3.6.1.4.1.99999.1", 1);
    if (oid == NULL) {
        return nil;
    }

    int cmp = OBJ_cmp(oid, vote->alg->algorithm);
    ASN1_OBJECT_free(oid);

    if (cmp != 0) {
        return nil;
    }

    Element *uBlind = [[ECCElement alloc] initWithASN:vote->cipher->uBlind
                                                group:self];
    Element *vBlindedMsg = [[ECCElement alloc] initWithASN:vote->cipher->vBlindedMsg
                                                     group:self];
    ret = [[Ballot alloc] initWithName:ballotName uBlind:uBlind vBlindedMsg:vBlindedMsg];
    return ret;
}

- (void) dealloc
{
    DLog(@"ECCGroup dealloc");
    EC_GROUP_free(_ecg);
}

@end


@implementation ECCElement

- (id) decodeFromBytes:(const unsigned char*) data
                length:(long) length
                 group:(ECCGroup*) group
{
    ECCElement *retval = nil;
    BIGNUM* xx = NULL;
    BIGNUM* yy = NULL;
    BN_CTX* ctx = NULL;
    EC_POINT* tmp = NULL;

    if ((data == NULL) || (group == nil)) {
        goto error;
    }

    // Ensure the point is in uncompressed form (starts with 0x04)
    if (length < 1 || data[0] != 0x04) {
        goto error;
    }

    const int coord_len = (int)((length - 1) / 2);
    const unsigned char* x_data = data + 1;
    const unsigned char* y_data = x_data + coord_len;

    xx = BN_new();
    if (!xx) {
        goto error;
    }

    yy = BN_new();
    if (!yy) {
        goto error;
    }

    if (!BN_bin2bn(x_data, coord_len, xx)) {
        goto error;
    }

    if (!BN_bin2bn(y_data, (int)length - 1 - coord_len, yy)) {
        goto error;
    }

    ctx = BN_CTX_new();
    if (!ctx) {
        goto error;
    }

    tmp = EC_POINT_new(group.ecg);
    if (!tmp) {
        goto error;
    }

    if (!EC_POINT_set_affine_coordinates(group.ecg, tmp, xx, yy, ctx)) {
        goto error;
    }

    _group = group;
    _value = tmp;
    tmp = NULL;
    retval = self;

error:
    BN_free(xx);
    BN_free(yy);
    BN_CTX_free(ctx);
    EC_POINT_clear_free(tmp);
    return retval;
}



- (id) initWithValue:(const EC_POINT*) value
               group:(ECCGroup*) group
{
    self = [super init];

    if ((value == NULL) || (group == nil)) {
        return nil;
    }

    _value = EC_POINT_dup(value, group.ecg);
    if (_value == NULL) {
        return nil;
    }

    _group = group;
    return self;
}

- (id) initWithECCBytes:(const unsigned char*) data
              length:(long)length
               group:(ECCGroup*) group
{
    self = [super init];
    return [self decodeFromBytes:data length:length group:group];
}


- (id) initWithASN:(const ASN1_OCTET_STRING *) asn
             group:(ECCGroup *) group
{
    self = [super init];
    if (asn == NULL) {
        return nil;
    }

    return [self decodeFromBytes:asn->data length:asn->length group:group];
}

- (ECCElement*) scaleWithScalar:(Scalar*) scalar
{
    ECCElement *ret = nil;
    EC_POINT *tmp = EC_POINT_new(_group.ecg);
    BN_CTX *ctx = BN_CTX_new();
    BIGNUM *bn_zero = BN_new();

    if ((scalar == nil) || (tmp == NULL) || (ctx == NULL) || (bn_zero == NULL)) {
        goto error;
    }

    if (!BN_set_word(bn_zero, 0)) {
        goto error;
    }

    // FIXME: bn_zero not needed?
    if (!EC_POINT_mul(_group.ecg, tmp, bn_zero, _value, scalar.value, ctx)) {
        goto error;
    }

    ret = [[ECCElement alloc] initWithValue:tmp group:_group];

error:

    EC_POINT_clear_free(tmp);
    BN_CTX_free(ctx);
    BN_free(bn_zero);

    return ret;
}

- (ECCElement*) operationWithElement:(ECCElement*) other
{
    ECCElement *ret = nil;
    EC_POINT *tmp = EC_POINT_new(_group.ecg);
    BN_CTX *ctx = BN_CTX_new();

    if ((other == nil) || (tmp == NULL) || (ctx == NULL)) {
        goto error;
    }

    // Point addition (x1+x2, y1+y2) on a curve
    if (!EC_POINT_add(_group.ecg, tmp, _value, other->_value, ctx)) {
        goto error;
    }

    ret = [[ECCElement alloc] initWithValue:tmp group:_group];

error:

    EC_POINT_clear_free(tmp);
    BN_CTX_free(ctx);

    return ret;
}

- (ECCElement*) inverse
{
    ECCElement *ret = nil;
    EC_POINT *tmp = EC_POINT_dup(_value, _group.ecg);
    BN_CTX *ctx = BN_CTX_new();

    if ((tmp == NULL) || (ctx == NULL)) {
        goto error;
    }

    if (!EC_POINT_invert(_group.ecg, tmp, ctx)) {
        goto error;
    }

    ret = [[ECCElement alloc] initWithValue:tmp group:_group];

error:

    EC_POINT_clear_free(tmp);
    BN_CTX_free(ctx);

    return ret;
}

- (bool) equalsWithElement:(ECCElement*) other
{
    bool retval = false;
    BN_CTX* ctx = BN_CTX_new();

    if ((other == nil) || (ctx == NULL))  {
        goto error;
    }

    if (EC_POINT_cmp(_group.ecg, _value, other->_value, ctx) != 0) {
        goto error;
    }
    retval =  true;

error:

    BN_CTX_free(ctx);
    return retval;
}


- (NSString*) decode {

    NSString *retval = nil;
    NSData *data = nil;
    int ii = 0;
    BIGNUM *xx = BN_new();
    BIGNUM *fieldOrder = BN_new();
    BIGNUM *shiftedX = BN_new();
    BN_CTX* ctx = BN_CTX_new();
    int byteLength = 0;
    unsigned char *xBytes = NULL;

    if ((xx == NULL) || (fieldOrder == NULL) || (shiftedX == NULL) || (ctx == NULL))  {
        goto error;
    }

    // Get affine x-coordinate
    if (!EC_POINT_get_affine_coordinates(_group.ecg, _value, xx, NULL, ctx)) {
        goto error;
    }

    // Get field order
    if (!BN_copy(fieldOrder, EC_GROUP_get0_order(_group.ecg))) {
        goto error;
    }

    int fieldBitLength = BN_num_bits(fieldOrder);
    int xBitLength = BN_num_bits(xx);

    if (xBitLength != fieldBitLength - 1) {
        goto error;
    }

    // Strip field encoding bits
    if (!BN_rshift(shiftedX, xx, 10)) {
        goto error;
    }

    // Convert BIGNUM to bytes
    byteLength = BN_num_bytes(shiftedX);
    xBytes = malloc(byteLength);
    if (!xBytes) {
        goto error;
    }

    if (!BN_bn2bin(shiftedX, xBytes)) {
        goto error;
    }

    // Inspect first byte
    unsigned char firstByte = xBytes[0] >> 1;
    int leadingZerosCount = (firstByte == 0) ? 8 : __builtin_clz((unsigned int)firstByte) - 24;
    int onesCount = __builtin_popcount(firstByte);

    if (8 - onesCount != leadingZerosCount) {
        goto error;
    }

    // Strip padding bytes
    for (ii = 1; ii < byteLength; ii++) {
        switch (xBytes[ii]) {
            case 0xFF: // Padding byte
                break;
            case 0xFE: // End of padding
                if (ii + 1 == byteLength) {
                    data = [NSData data];
                } else {
                    data = [NSData dataWithBytes:&xBytes[ii + 1] length:(byteLength - ii - 1)];
                }
                goto end;
            default:
                goto error;
        }
    }

end:

    if (data) {
        retval = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

error:

    BN_clear_free(xx);
    BN_clear_free(fieldOrder);
    BN_clear_free(shiftedX);
    BN_CTX_free(ctx);
    free(xBytes);

    return retval;
}

- (void) dealloc
{
    DLog(@"ECCElement dealloc");
    _group = nil;
    EC_POINT_clear_free(_value);
}

@end
