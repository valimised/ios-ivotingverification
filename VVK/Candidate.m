//
//  Candidate.m
//  VVK

#import "Candidate.h"

@implementation Candidate

@synthesize name=_name;
@synthesize party=_party;
@synthesize number=_number;

- (id) initWithNumber:(NSString*)number
                party:(NSString*)party
                 name:(NSString*)name
{
    self = [super init];

    if (self) {
        _number = number;
        _party = party;
        _name = name;
    }

    return self;
}

- (void) dealloc
{
    _name = nil;
    _number = nil;
    _party = nil;
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"<Candidate: %p> {name: %@, party: %@, number: %@}", self, _name, _party, _number];
}

@end
