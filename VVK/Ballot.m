//
//  Ballot.m
//  VVK

#import "Ballot.h"

@implementation Ballot

@synthesize name=_name;
@synthesize uBlind=_uBlind;
@synthesize vBlindedMsg=_vBlindedMsg;

- (id) initWithName:(NSString*)ballotName
             uBlind:(Element*)uBlind
        vBlindedMsg:(Element*)vBlindedMsg
{
    _name = ballotName;
    _uBlind = uBlind;
    _vBlindedMsg = vBlindedMsg;
    return self;
}

- (void) dealloc
{
    DLog(@"");
    _name = nil;
    _uBlind = nil;
    _vBlindedMsg = nil;

}

@end
