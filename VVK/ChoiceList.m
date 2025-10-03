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

- (Candidate*)findCandidate:(NSString*)number
{
    for (NSString *party in choiceList) {
        NSDictionary *members = choiceList[party];
        if (members[number]) {
            return [[Candidate alloc] initWithNumber:number party:party name:members[number]];
        }
    }
    return nil;
}

- (void) dealloc
{
    choiceList = nil;
}

@end
