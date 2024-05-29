//
//  Ballot.m
//  VVK

#import <openssl/x509.h>

#import "Ballot.h"

@implementation Ballot

@synthesize name;
@synthesize vote;

- (id) initWithName:(NSString*)ballotName andVote:(NSData*)voteCipher;
{
    self = [super init];

    if (self) {
        name = ballotName;

        BIO* cBio = BIO_new_mem_buf([voteCipher bytes], (int)[voteCipher length]);
        vote = d2i_ELGAMAL_CIPHER_bio(cBio, NULL);
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
    }

    return self;
}

- (void) dealloc
{
    DLog(@"");
    name = nil;
    vote = nil;
}

@end
