//
//  Crypto.h
//  VVK
//
//  Created by Eigen Lenk on 2/4/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Crypto : NSObject

+ (NSData *)hexToString:(NSString *)hexString;
+ (NSString *)stringToHex:(NSString *)string;

+ (NSString *)encryptVote:(in NSString *)vote withSeed:(in NSString *)seed;

+ (BOOL)initPublicKey:(in NSString *)publicKey;
+ (BOOL)clearPublicKey;

@end
