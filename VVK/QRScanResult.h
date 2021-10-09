//
//  QRScanResult.h
//  VVK

#import <Foundation/Foundation.h>

@interface QRScanResult : NSObject
{
@private
    __strong NSString* logId;
    __strong NSData* rndSeed;
    __strong NSString* sessionId;
}

@property (nonatomic, readonly) NSString* logId;
@property (nonatomic, readonly) NSData* rndSeed;
@property (nonatomic, readonly) NSString* sessionId;

- (id) initWithSymbolData:(NSString*)symbolData;

@end
