//
//  Vote.h
//  VVK
//
//  Created by Eigen Lenk on 1/30/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ALCustomAlertView.h"

@interface Ballot : NSObject
{
    @private
    __strong NSString * name;
    __strong NSString * hex;
}

#pragma mark - Properties

@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) NSString * hex;


#pragma mark - Methods

- (id)initWithName:(NSString *)ballotName andHex:(NSString *)hexCode;

- (NSString *)description;

@end


#pragma mark -

@interface Candidate : NSObject
{
    __strong NSString * name;
    __strong NSString * party;
    __strong NSString * number;
    __weak Ballot * ballot;
}

#pragma mark - Properties

@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) NSString * party;
@property (nonatomic, readonly) NSString * number;
@property (nonatomic, readonly) Ballot * ballot;


#pragma mark - Methods

- (id)initWithComponents:(NSArray *)components andElection:(in Ballot *)election;

@end


#pragma mark -

@class QRScanResult;

@interface VoteContainer : NSObject <RequestDelegate, ALCustomAlertViewDelegate>
{
    @private
    __strong QRScanResult * scanResult;
    __strong NSDictionary * ballots;
    __strong NSArray * candidates;
    NSInteger versionNumber;
    NSInteger controlState;
}

#pragma mark - Properties

@property (nonatomic, readonly) NSDictionary * ballots;
@property (nonatomic, readonly) NSArray * candidates;
@property (nonatomic, readonly) QRScanResult * scanResult;


#pragma mark - Methods

- (id)initWithScanResult:(QRScanResult *)result;

- (void)download;

- (NSArray *)bruteForceVerification;

@end
