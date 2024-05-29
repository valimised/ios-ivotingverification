//
//  IVXVRequest.h 
//  iVotingVerification

@interface IVXVRequest : NSObject

- (id _Nonnull ) initWithCerts:(NSArray * _Nonnull)certStrArray;

- (void)resetWithTimeout:(int)timeout;

- (void)sendHandshake:(NSString *_Nonnull)connStr
               sniStr:(NSString *_Nonnull)sniStr
           completion:(void (^_Nonnull)(NSError * _Nullable error))completion;

- (void)sendRequest:(NSData *_Nonnull)requestData
         completion:(void (^_Nonnull)(NSData * _Nullable responseData, NSError * _Nullable error))completion;

@end
