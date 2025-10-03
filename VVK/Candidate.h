//
//  Candidate.h
//  VVK

@interface Candidate : NSObject
{
    NSString* _name;
    NSString* _party;
    NSString* _number;
}

#pragma mark - Properties

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSString* party;
@property (nonatomic, readonly) NSString* number;

#pragma mark - Methods

- (id) initWithNumber:(NSString*)number party:(NSString*) party name:(NSString*) name;

@end
