//
//  QRScanResult.m
//  VVK

#import "QRScanResult.h"

@implementation QRScanResult

@synthesize logId;
@synthesize rndSeed;
@synthesize sessionId;

- (id)initWithSymbolData:(NSString *)symbolData
{
    self = [super init];
    
    if (self)
    {
        DLog(@"Symbol data: %@", symbolData);
        
        NSArray * components = [symbolData componentsSeparatedByString:@"\n"];
        
        if ([components count] != 3) {
            return nil;
        }

        logId = components[0];
        rndSeed = [[NSData alloc] initWithBase64EncodedString:components[1] options:0];
        sessionId = components[2];
    }
    
    return self;
}

- (void)dealloc
{
    logId = nil;
    rndSeed = nil;
    sessionId = nil;
}

@end
