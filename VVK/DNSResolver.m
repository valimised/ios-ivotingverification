//
//  DNSResolver.m
// Based on https://eggerapps.at/blog/2014/hostname-lookups.html

#import "DNSResolver.h"
#import <arpa/inet.h>

@implementation DNSResolver {
    BOOL done;
}

- (BOOL) lookup
{
    // sanity check
    if (!self.hostname) {
        self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@ {NSLocalizedDescriptionKey:@"No hostname provided."}];
        return NO;
    }

    NSArray* urlComponents = [self.hostname componentsSeparatedByString:@":"];
    // set up the CFHost object
    CFHostRef host = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)urlComponents[0]);
    CFHostClientContext ctx = {.info = (__bridge void*)self};
    CFHostSetClient(host, DNSResolverHostClientCallback, &ctx);
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFHostScheduleWithRunLoop(host, runloop, CFSTR("DNSResolverRunLoopMode"));
    // start the name resolution
    CFStreamError error;
    Boolean didStart = CFHostStartInfoResolution(host, kCFHostAddresses, &error);

    if (!didStart) {
        self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@ {NSLocalizedDescriptionKey:@"CFHostStartInfoResolution failed."}];
        return NO;
    }

    // run the run loop for 50ms at a time, always checking if we should cancel
    while (!done) {
        CFRunLoopRunInMode(CFSTR("DNSResolverRunLoopMode"), 0.05, true);
    }

    if (!self.error) {
        Boolean hasBeenResolved;
        CFArrayRef addressArray = CFHostGetAddressing(host, &hasBeenResolved);

        if (hasBeenResolved) {
            NSMutableArray* tmp = [[NSMutableArray alloc] initWithCapacity:CFArrayGetCount(addressArray)];

            for (int i = 0; i < CFArrayGetCount(addressArray); i++) {
                struct sockaddr_in* remoteAddr;
                CFDataRef saData = (CFDataRef)CFArrayGetValueAtIndex(addressArray, i);
                remoteAddr = (struct sockaddr_in*)CFDataGetBytePtr(saData);

                if (remoteAddr != NULL) {
                    NSString* strDNS = [NSString stringWithCString:inet_ntoa(remoteAddr->sin_addr) encoding:
                                                 NSASCIIStringEncoding];
                    [tmp addObject:[[strDNS stringByAppendingString:@":"] stringByAppendingString:urlComponents[1]]];
                }
            }

            self.addresses = [tmp copy];
        }
        else {
            self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@ {NSLocalizedDescriptionKey:@"Name look up failed"}];
        }
    }

    // clean up the CFHost object
    CFHostSetClient(host, NULL, NULL);
    CFHostUnscheduleFromRunLoop(host, runloop, CFSTR("DNSResolverRunLoopMode"));
    CFRelease(host);
    return self.error ? NO : YES;
}

void DNSResolverHostClientCallback ( CFHostRef theHost, CFHostInfoType typeInfo,
                                     const CFStreamError* error, void* info)
{
    DNSResolver* self = (__bridge DNSResolver*)info;

    if (error->domain || error->error)
        self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@ {NSLocalizedDescriptionKey:@"Name look up failed"}];
    self->done = YES;
}

@end
