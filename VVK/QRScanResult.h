//
//  QRScanResult.h
//  VVK
//
//  Created by Eigen Lenk on 2/4/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VerificationEntry : NSObject
{
    @private
    __strong NSString * electionIdentificator;
    __strong NSString * hex;
}

@property (nonatomic, readonly) NSString * electionIdentificator;
@property (nonatomic, readonly) NSString * hex;

- (id)initWithIdentificator:(NSString *)identificator andHex:(NSString *)hexCode;

@end


@interface QRScanResult : NSObject
{
    @private
    __strong NSString * voteIdentificator;
    __strong NSArray * verificationEntries;
}

@property (nonatomic, readonly) NSString * voteIdentificator;
@property (nonatomic, readonly) NSArray * verificationEntries;

- (id)initWithSymbolData:(NSString *)symbolData;

@end
