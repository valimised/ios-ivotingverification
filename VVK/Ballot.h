//
//  Ballot.h
//  VVK

#import <Foundation/Foundation.h>

@class Element;

@interface Ballot : NSObject
{
@private
    __strong NSString* _name;
    Element *_uBlind;
    Element *_vBlindedMsg;
}

// MARK: - Properties

@property (nonatomic, readonly) NSString* name;
@property (atomic, readonly) Element* uBlind;
@property (atomic, readonly) Element* vBlindedMsg;

// MARK: - Methods

- (id) initWithName:(NSString*)ballotName
             uBlind:(Element*)uBlind
        vBlindedMsg:(Element*)vBlindedMsg;

@end
