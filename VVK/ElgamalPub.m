//
//  ElgamalPub.m
//  VVK

#import "ElgamalPub.h"
#import "Ballot.h"
#import "GroupECC.h"
#import "GroupModP.h"
#import <openssl/asn1.h>
#import <openssl/x509.h>

#define BEGIN_KEY @"-----BEGIN PUBLIC KEY-----"
#define END_KEY @"-----END PUBLIC KEY-----"

// oid: 1.3.6.1.4.1.3029.2.1
#define MODP_ELGAMAL_OID "\x2b\x06\x01\x04\x01\x97\x55\x02\x01"
#define ECC_ELGAMAL_OID "\x2b\x06\x01\x04\x01\x86\x8d\x1f\x01"

@implementation ElgamalPub

@synthesize group;
@synthesize y;
@synthesize elId;

// MARK: - Helper Methods

- (NSString *)preprocessPemString:(NSString *)pemStr {
    pemStr = [pemStr stringByReplacingOccurrencesOfString:BEGIN_KEY withString:@""];
    pemStr = [pemStr stringByReplacingOccurrencesOfString:END_KEY withString:@""];
    return pemStr.length > 0 ? pemStr : nil;
}

- (BOOL)readASN1Object:(const unsigned char **)stream
                length:(long *)len
                exptag:(int)exptag
            dataLength:(NSUInteger)dataLength {
    int tag, xclass = 0;
    int status = ASN1_get_object(stream, len, &tag, &xclass, dataLength);
    return !(status == 0x80 || tag != exptag);
}

- (id)initializeModPGroupWithStream:(const unsigned char **)stream
                         dataLength:(NSUInteger)dataLength {
    long len = 0;
    BIGNUM *p = NULL;
    BIGNUM *g = NULL;
    ModPGroup *modpGroup = nil;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_SEQUENCE
                   dataLength:dataLength]) goto error;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_INTEGER
                   dataLength:dataLength]) goto error;

    p = BN_bin2bn(*stream, (int)len, NULL);
    if (!p) goto error;
    *stream += len;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_INTEGER
                   dataLength:dataLength]) goto error;

    g = BN_bin2bn(*stream, (int)len, NULL);
    if (!g) goto error;
    *stream += len;

    modpGroup = [[ModPGroup alloc] initWithParams:p generator:g];
    if (modpGroup == nil) goto error;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_GENERALSTRING
                   dataLength:dataLength]) goto error;

    elId = [[NSString alloc] initWithBytes:*stream length:len encoding:NSUTF8StringEncoding];
    *stream += len;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_BIT_STRING
                   dataLength:dataLength]) goto error;

    if ((*stream)[0] != 0) goto error; // Validate leading zero

    (*stream)++;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_SEQUENCE
                   dataLength:dataLength]) goto error;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_INTEGER
                   dataLength:dataLength]) goto error;

    y = [[ModPElement alloc] initWithModPBytes:*stream length:len group:modpGroup];
    if (!y) goto error;

    group = modpGroup;

error:
    BN_free(p);
    BN_free(g);

    if (group) {
        return self;
    }

    return nil;
}

- (id)initializeECCGroupWithStream:(const unsigned char **)stream
                        dataLength:(NSUInteger)dataLength {
    long len = 0;
    NSString *curveName = nil;
    ECCGroup *eccGroup = nil;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_SEQUENCE
                   dataLength:dataLength]) goto error;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_GENERALSTRING
                   dataLength:dataLength]) goto error;

    curveName = [[NSString alloc] initWithBytes:*stream
                                         length:len
                                       encoding:NSUTF8StringEncoding];
    *stream += len;

    eccGroup = [[ECCGroup alloc] initWithName:curveName];

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_GENERALSTRING
                   dataLength:dataLength]) goto error;

    elId = [[NSString alloc] initWithBytes:*stream
                                    length:len
                                  encoding:NSUTF8StringEncoding];
    *stream += len;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_BIT_STRING
                   dataLength:dataLength]) goto error;

    if ((*stream)[0] != 0) goto error; // Validate leading zero

    (*stream)++;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_SEQUENCE
                   dataLength:dataLength]) goto error;

    if (![self readASN1Object:stream
                       length:&len
                       exptag:V_ASN1_OCTET_STRING
                   dataLength:dataLength]) goto error;

    y = [[ECCElement alloc] initWithECCBytes:*stream length:len group:eccGroup];
    if (!y) goto error;

    group = eccGroup;

error:

    if (group) {
        return self;
    }

    return nil;
}

// MARK: - ElgamalPub methods

- (id) init
{
    group = nil;
    y = nil;
    elId = nil;
    return self;
}

- (id)initWithPemString:(NSString *)pemStr {
    self = [super init];
    if (!self) return nil;

    NSString *cleanedPemStr = [self preprocessPemString:pemStr];
    if (!cleanedPemStr) return nil;

    NSDataBase64DecodingOptions options = NSDataBase64DecodingIgnoreUnknownCharacters;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:cleanedPemStr
                                                       options:options];
    if (!data) return nil;

    const unsigned char *stream = (const unsigned char *)[data bytes];
    long len = 0;

    if (![self readASN1Object:&stream
                       length:&len
                       exptag:V_ASN1_SEQUENCE
                   dataLength:[data length]]) return nil;

    if (![self readASN1Object:&stream
                       length:&len
                       exptag:V_ASN1_SEQUENCE
                   dataLength:[data length]]) return nil;

    if (![self readASN1Object:&stream
                       length:&len
                       exptag:V_ASN1_OBJECT
                   dataLength:[data length]]) return nil;

    char oid[len];
    memcpy(oid, stream, len);
    stream += len;

    BOOL isModP = strncmp(oid, MODP_ELGAMAL_OID, len) == 0;
    BOOL isECC = strncmp(oid, ECC_ELGAMAL_OID, len) == 0;

    if (isModP) {
        return [self initializeModPGroupWithStream:&stream dataLength:[data length]];
    } else if (isECC) {
        return [self initializeECCGroupWithStream:&stream dataLength:[data length]];
    }

    return nil;
}

- (Element*) decryptBallot:(Ballot*)ballot
                randomness:(Scalar*)randomness
{
    return [self decryptCiphertextvBlindedMsg:ballot.vBlindedMsg
                                       uBlind:ballot.uBlind
                                   randomness:randomness];
}

- (Element*) decryptCiphertextvBlindedMsg:(Element*)vBlindedMsg
                                   uBlind:(Element*)uBlind
                               randomness:(Scalar*)randomness
{
    Element * generator = nil;
    Element *gr = nil;
    Element *factor = nil;
    Element* factorInverse = nil;
    Element* ret = nil;

    if ((vBlindedMsg == nil) || (uBlind == nil) || (randomness == nil)) {
        goto end;
    }

    // https://gitlab.anu.edu.au/u1113289/thomas-public-paper/-/raw/master/Estonia_IVXV_June2022.pdf
    generator = [group generator];
    if (generator == nil) {
        goto end;
    }

    gr = [generator scaleWithScalar:randomness];
    if (gr == nil) {
        goto end;
    }

    if (![uBlind equalsWithElement:gr]) {
        DLog(@"uBLind randomness check failed");
        goto end;
    }

    factor = [y scaleWithScalar:randomness];
    if (factor == nil) {
        goto end;
    }

    factorInverse = [factor inverse];
    if (factorInverse == nil) {
        goto end;
    }

    ret = [factorInverse operationWithElement:vBlindedMsg];

end:
    return ret;
}

- (void) dealloc
{
    DLog(@"key dealloc");
    group = nil;
    y = nil;
    elId = nil;
}

@end
