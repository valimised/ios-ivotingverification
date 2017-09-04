//
//  TlsSocket.h
//  VVK

#import <Foundation/Foundation.h>

@interface TlsSocket : NSObject {
    __strong NSInputStream* inStream;
    __strong NSOutputStream* outStream;
    NSArray* certs;
    __strong NSMutableData* data;
}

@property (nonatomic, readonly) NSInputStream* inStream;
@property (nonatomic, readonly) NSOutputStream* outStream;
@property (nonatomic, readonly) NSArray* certs;
@property (nonatomic, readonly) NSMutableData* data;


- (id)initWithHost:(NSString *)hostname ip:(NSString *)ip port:(NSInteger)port certStrArray:(NSArray *)certStrArray;
- (void)setDelegate:(id<NSStreamDelegate>)delegate;
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode;
- (void)open;

@end
