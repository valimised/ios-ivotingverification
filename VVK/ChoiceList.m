//
//  ChoiceList.m
//  VVK

#import "ChoiceList.h"

@implementation ChoiceList


- (id) initWithBase64:(NSString*)base64
{
    self = [super init];

    if (self) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
        if (data == nil) {
            return nil;
        }

        NSError* error = nil;
        choiceList = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

        if (error != nil) {
            return nil;
        }

        if (choiceList == nil) {
            return nil;
        }
    }

    return self;
}

- (bool)isValidCandidate:(Candidate*)candidate
{
    if ([choiceList[candidate.party] isKindOfClass:[NSDictionary class]]) {
        NSString* nameInList = choiceList[candidate.party][candidate.number];
        if (nameInList != nil) {
            NSComparisonResult res = [nameInList compare:candidate.name options:NSLiteralSearch];
            if (res == NSOrderedSame) {
                return true;
            }
        }
    }
    return false;
}


- (void) dealloc
{
    choiceList = nil;
}

@end
