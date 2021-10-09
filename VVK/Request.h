//
//  Request.h
//  iVotingVerification

#import <Foundation/Foundation.h>

@class Request;

const static NSString* kRequestType = @"requestType";
const static NSString* kRequestPOST = @"POST";


@protocol RequestDelegate <NSObject>

@optional

#pragma mark - Authentication

- (void) request:(Request*)request didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge
    completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition disposition,
    NSURLCredential* credential))completionHandler;


#pragma mark Result

- (void) requestDidFinish:(Request*)request withError:(NSError*)error;

@end

#pragma mark -

@interface Request : NSObject <NSURLSessionDataDelegate>
{
@private
    __strong NSMutableURLRequest* request;
    __strong NSDictionary* responseHeaders;
    __strong NSData* postData;
    __strong NSInputStream* httpBodyInputStream;
    __strong NSString* validHost;
    __weak id<RequestDelegate> delegate;
    __weak id<RequestDelegate> authenticationDelegate;
    NSInteger responseStatusCode;
}


#pragma mark - Properties

@property (nonatomic, readonly) NSMutableData* responseData;
@property (nonatomic, readonly) NSMutableURLRequest* request;
@property (nonatomic, readonly) NSDictionary* responseHeaders;
@property (nonatomic, readonly) NSInteger responseStatusCode;
@property (nonatomic) NSString* validHost;
@property (nonatomic, weak) id<RequestDelegate> delegate;
@property (nonatomic, weak) id<RequestDelegate> authenticationDelegate;


#pragma mark - Initialization

// Main initializer
- (id) initWithURL:(NSURL*)url options:(NSDictionary*)options;

// Calls initWithURL:... options:nil
- (id) initWithHost:(NSString*)host path:(NSString*)path;

// Calls initWithURL:... options:nil
- (id) initWithURL:(NSURL*)url;


#pragma mark Public methods

- (void) start;

@end
