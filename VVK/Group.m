//
//  ElgamalPub.m
//  VVK

#import "Group.h"

@implementation Group

- (id) init
{
    self = [super init];

    return self;
}

- (void) dealloc
{
}

- (Element*) generator
{
    return nil;
}

- (Element*) elementOfASN1:(NSData*)data
{
    return nil;
}

- (Ballot*) decodeBallotWithName:(NSString*)ballotName
                      ciphertext:(NSData*)ciphertext
{
    return nil;
}

@end


@implementation Element

- (id) init
{
    self = [super init];

    return self;
}

- (Element*) scaleWithScalar:(Scalar*) scalar
{
    return nil;
}

- (Element*) operationWithElement:(Element*) other
{
    return nil;
}

- (Element*) inverse
{
    return nil;
}

- (bool) equalsWithElement:(Element*) other
{
    return nil;
}

- (NSString*) decode
{
    return nil;
}

- (void) dealloc
{
}

@end
