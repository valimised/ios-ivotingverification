//
//  Candidate.m
//  VVK

#import "Candidate.h"

@implementation Candidate

@synthesize name;
@synthesize party;
@synthesize number;

- (id) initWithComponents:(in NSArray*)components
{
    self = [super init];

    if (self) {
        number = components[0];
        party = components[1];
        name = components[2];
    }

    return self;
}

- (void) dealloc
{
    name = nil;
    number = nil;
    party = nil;
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"<Candidate: %p> {name: %@, party: %@, number: %@}", self, name,
                     party, number];
}

@end
