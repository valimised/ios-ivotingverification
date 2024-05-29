//
//  Candidate.h
//  VVK

@interface Candidate : NSObject
{
    __strong NSString* name;
    __strong NSString* party;
    __strong NSString* number;
}

#pragma mark - Properties

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* party;
@property (nonatomic, readonly) NSString* number;

#pragma mark - Methods

- (id) initWithComponents:(NSArray*)components;

@end
