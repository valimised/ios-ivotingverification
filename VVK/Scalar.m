//
//  Scalar.m
//  VVK
//
//  Created by Sven Heiberg on 29.11.2024.
//

#import "Scalar.h"

@implementation Scalar

@synthesize value=_value;

- (id) initWithValue:(BIGNUM*) value
               group:(Group*) group

{
    BIGNUM *tmp_value = NULL;

    if ((value == NULL) || (group == nil)) {
        goto error;
    }

    tmp_value = BN_dup(value);
    if (tmp_value == NULL) {
        goto error;
    }

    _value = tmp_value;
    _group = group;
    return self;

error:
    BN_clear_free(tmp_value);
    return nil;
}

- (id) initWithBytes:(NSData*) value_bytes
               group:(Group*) group
{
    BIGNUM *tmp_value = NULL;

    if ((value_bytes == nil) || (group == nil)) {
        goto error;
    }

    tmp_value = BN_bin2bn([value_bytes bytes], (int)[value_bytes length], NULL);
    if (tmp_value == NULL) {
        goto error;
    }

    _value = tmp_value;
    _group = group;
    return self;

error:
    BN_clear_free(tmp_value);
    return nil;
}

- (void) dealloc
{
    DLog(@"Scalar dealloc");
    BN_clear_free(_value);
}

@end
