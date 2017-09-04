//
//  TlsSocket.m
//  VVK

#import "TlsSocket.h"

@interface TlsSocket (Private)
- (SecCertificateRef)parseCertString:(NSString*)certStr;
@end

@implementation TlsSocket

@synthesize inStream;
@synthesize outStream;
@synthesize certs;
@synthesize data;

-(id)initWithHost:(NSString *)hostname ip:(NSString *)ip port:(NSInteger)port certStrArray:(NSArray*)certStrArray {
    self = [super init];
    if (self) {
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)(ip), (int)port, &readStream, &writeStream);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);
        NSDictionary* sslSettings = @{(id)kCFStreamSSLValidatesCertificateChain: (id) kCFBooleanFalse, (id)kCFStreamSSLPeerName: (id)hostname};
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (__bridge CFTypeRef)(sslSettings));
        inStream = (__bridge_transfer NSInputStream *)readStream;
        outStream = (__bridge_transfer NSOutputStream *)writeStream;
        data = [[NSMutableData alloc] init];
        NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:[certStrArray count]];
        for (NSString* cert in certStrArray) {
            [tmp addObject:(__bridge id)[self parseCertString:cert]];
        }
        certs = [NSArray arrayWithArray:tmp];
        for (int i = 0; i < [tmp count]; i++) {
            CFRelease((__bridge CFTypeRef)([tmp objectAtIndex:i]));
        }
        tmp = NULL;
        if (certs == NULL || [certs count] != [certStrArray count]) {
            return nil;
        }
    }
    return self;
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate {
    [inStream setDelegate:delegate];
    [outStream setDelegate:delegate];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {
    [inStream scheduleInRunLoop:aRunLoop forMode:mode];
    [outStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)open {
    [inStream open];
    [outStream open];
}

-(SecCertificateRef)parseCertString:(NSString*)certStr {
    NSArray* array = [certStr componentsSeparatedByString:@"\n"];
    NSString* base64Str = [[array subarrayWithRange:NSMakeRange(1, [array count] - 2)] componentsJoinedByString:@""];
    NSData *certData = [[NSData alloc] initWithBase64EncodedString:base64Str options:0];

    return SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)certData);;
}
@end
