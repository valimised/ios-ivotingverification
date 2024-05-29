//
//  Vote.h
//  VVK

#import <Foundation/Foundation.h>

#import "ALCustomAlertView.h"
#import "ChoiceList.h"
#import "QRScanResult.h"

@interface VoteContainer : NSObject <ALCustomAlertViewDelegate>
{
@private
    __strong QRScanResult* scanResult;
    __strong NSMutableArray* ballots;
}

#pragma mark - Properties

@property (nonatomic, readonly) QRScanResult* scanResult;
@property (nonatomic, readonly) NSMutableArray* ballots;
@property(nonatomic, readonly) ChoiceList* choiceList;

#pragma mark - Methods

- (id) initWithScanResult:(QRScanResult*)result;

- (void) download;

- (NSDictionary*) ballotDecryptionWithRandomness;

@end
