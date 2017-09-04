//
//  Crypto.h
//  VVK

#import <Foundation/Foundation.h>
#import <openssl/bn.h>

#import "ElgamalPub.h"

@interface Crypto : NSObject

+ (NSData *)hexToString:(NSString *)hexString;
+ (NSString *)stringToHex:(NSString *)string;

+ (NSString *)decryptVote:(unsigned char *)vote voteLen:(int)len withRnd:(NSData *)rnd key:(ElgamalPub *)pub;

@end
