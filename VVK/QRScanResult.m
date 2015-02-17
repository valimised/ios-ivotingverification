//
//  QRScanResult.m
//  VVK
//
//  Created by Eigen Lenk on 2/4/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "QRScanResult.h"

@implementation VerificationEntry

@synthesize electionIdentificator;
@synthesize hex;

- (id)initWithIdentificator:(NSString *)identificator andHex:(NSString *)hexCode
{
    self = [super init];
    
    if (self)
    {
        electionIdentificator = identificator;
        hex = hexCode;
        
        DLog(@"electionIdentificator = %@", electionIdentificator);
        DLog(@"hex = %@", hex);
        DLog(@" ");
    }
    
    return self;
}

@end




@implementation QRScanResult

@synthesize voteIdentificator;
@synthesize verificationEntries;

- (id)initWithSymbolData:(NSString *)symbolData
{
    self = [super init];
    
    if (self)
    {
        DLog(@"Symbol data: %@", symbolData);
        
        NSArray * components = [symbolData componentsSeparatedByString:@"\n"];

        voteIdentificator = components[0];
        
        verificationEntries = [[NSArray alloc] init];
        
        for (NSUInteger i = 1; i < components.count; ++i)
        {
            if ([components[i] length] == 0)
                continue;
            
            NSArray * verificationEntryComponents = [components[i] componentsSeparatedByString:@"\t"];
            
            VerificationEntry * verificationEntry = [[VerificationEntry alloc] initWithIdentificator:verificationEntryComponents[0] andHex:verificationEntryComponents[1]];
            
            verificationEntries = [verificationEntries arrayByAddingObject:verificationEntry];
        }
    }
    
    return self;
}

- (void)dealloc
{
    verificationEntries = nil;
    voteIdentificator = nil;
}

@end
