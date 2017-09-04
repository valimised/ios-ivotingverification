//
//  ElgamalPub.m
//  VVK

#import "ElgamalPub.h"
#import <openssl/asn1.h>


#define BEGIN_KEY @"-----BEGIN PUBLIC KEY-----"
#define END_KEY @"-----END PUBLIC KEY-----"

// oid: 1.3.6.1.4.1.3029.2.1
#define ELGAMAL_OID "\x2b\x6\x1\x4\x1\x97\x55\x2\x1"

@implementation ElgamalPub

@synthesize p;
@synthesize q;
@synthesize g;
@synthesize y;
@synthesize elId;

- (id)initWithPemString:(NSString *)pemStr
{
    self = [super init];
    if (self) {
        pemStr = [pemStr stringByReplacingOccurrencesOfString:BEGIN_KEY withString:@""];
        pemStr = [pemStr stringByReplacingOccurrencesOfString:END_KEY withString:@""];
        NSData* data = [[NSData alloc] initWithBase64EncodedString:pemStr options:NSDataBase64DecodingIgnoreUnknownCharacters];
        
        const unsigned char* stream = (const unsigned char*)[data bytes];
        
        long len;
        int tag, xclass = 0;
        int j;
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_SEQUENCE) {
            return nil;
        }
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_SEQUENCE) {
            return nil;
        }
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_OBJECT) {
            return nil;
        }
        
        char oid[len];
        memcpy(oid, stream, len);
        stream = stream+len;
        
        if (strncmp(oid, ELGAMAL_OID, len) != 0) {
            return nil;
        }
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_SEQUENCE) {
            return nil;
        }
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_INTEGER) {
            return nil;
        }
        
        p = BN_bin2bn(stream, (int)len, NULL);
        
        if (p == nil) {
            return nil;
        }
        
        BIGNUM* tmp = BN_new();
        q = BN_new();
        BN_sub(tmp, p, BN_value_one());
        BN_rshift1(q, tmp);
        BN_clear_free(tmp);
        stream = stream + len;
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_INTEGER) {
            return nil;
        }
        
        g = BN_bin2bn(stream, (int)len, NULL);
        
        if (g == nil) {
            return nil;
        }
        
        stream = stream + len;
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_GENERALSTRING) {
            return nil;
        }
        
        elId = [[NSString alloc] initWithBytes:stream length:len encoding:NSUTF8StringEncoding];
        stream = stream + len;
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_BIT_STRING) {
            return nil;
        }
        
        // ASN1 Integer encoding of y has an 0 byte prepeneded
        if (stream[0] != 0) {
            return nil;
        }
        stream++;
        
        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);

        if (j == 0x80 || tag != V_ASN1_SEQUENCE) {
            return nil;
        }

        j = ASN1_get_object(&stream, &len, &tag, &xclass, [data length]);
        
        if (j == 0x80 || tag != V_ASN1_INTEGER) {
            return nil;
        }
        
        y = BN_bin2bn(stream, (int)len, NULL);
        
        
    }
    return self;
}

- (void)dealloc
{
    DLog(@"key dealloc");
    BN_clear_free(p);
    p = NULL;
    BN_clear_free(g);
    g = NULL;
    BN_clear_free(y);
    y = NULL;
    BN_clear_free(q);
    q = NULL;
    elId = nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: {p:%@, g:%@, y:%@}", elId, p, g, y];
}
@end
