//
//  ChoiceList.h
//  VVK

#import "Candidate.h"

@interface ChoiceList : NSObject
{
    __strong NSDictionary* choiceList;
}

#pragma mark - Methods

- (id) initWithBase64:(NSString*)base64;

- (bool)isValidCandidate:(Candidate*)candidate;

@end
