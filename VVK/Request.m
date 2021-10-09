//
//  Request.m
//  iVotingVerification

#import "Request.h"

@implementation Request

#pragma mark - Properties

@synthesize request;
@synthesize responseData;
@synthesize responseHeaders;
@synthesize responseStatusCode;
@synthesize validHost;
@synthesize delegate;
@synthesize authenticationDelegate;


#pragma mark - Initialization

- (id) initWithHost:(NSString*)host path:(NSString*)path
{
    return [self initWithURL:[NSURL URLWithString:[host stringByAppendingString:path]] options:nil];
}

- (id) initWithURL:(NSURL*)url
{
    return [self initWithURL:url options:nil];
}

- (id) initWithURL:(NSURL*)url options:(NSDictionary*)options
{
    self = [super init];

    if (self) {
        responseData = [NSMutableData data];
        request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData
                                       timeoutInterval:30.0];
        validHost = nil;

        if ([options[@"requestType"] isEqualToString:@"POST"]) {
            DLog(@"POST OPTIONS: %@", options[kRequestPOST]);
            NSString* urlEncodedPostData = [NSString stringWithFormat:@"verify=%@",
                                                     options[kRequestPOST][@"verify"]];  //[NSString URLEncodedStringWithDictionary:options[kRequestPOST]];
            DLog(@"urlEncodedPostData (%lu): %@", (unsigned long)[urlEncodedPostData length],
                 urlEncodedPostData);
            postData = [urlEncodedPostData dataUsingEncoding:NSUTF8StringEncoding];
            httpBodyInputStream = [NSInputStream inputStreamWithData:postData];
            [request setHTTPMethod:@"POST"];
            // [request setHTTPBody:postData];
            [request setHTTPBodyStream:httpBodyInputStream];
            [request addValue:[NSString stringWithFormat:@"%lu",
                               (unsigned long)postData.length] forHTTPHeaderField:@"Content-Length"];
            [request addValue:@"close" forHTTPHeaderField:@"Connection"];
        }
    }

    return self;
}

- (NSCachedURLResponse*) connection:(NSURLConnection*)connection willCacheResponse:
    (NSCachedURLResponse*)cachedResponse
{
    return nil;
}

- (void) dealloc
{
    request = nil;
    responseData = nil;
    responseHeaders = nil;
    delegate = nil;
    authenticationDelegate = nil;
    postData = nil;
    httpBodyInputStream = nil;
    validHost = nil;
}


#pragma mark - Public methods

- (void) start
{
    NSURLSessionConfiguration* sessionConfiguration = [NSURLSessionConfiguration
            defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self
                                          delegateQueue:[NSOperationQueue mainQueue]];
    [[session dataTaskWithRequest:request] resume];
}


#pragma mark - NSURLSessionDataDelegate

- (void) URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)dataTask didReceiveData:
    (NSData*)data
{
    [responseData appendData:data];
}

- (void) URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)dataTask
    didReceiveResponse:(NSURLResponse*)response completionHandler:(void(^)(
    NSURLSessionResponseDisposition))completionHandler
{
    // Store response headers
    responseHeaders = [(NSHTTPURLResponse*)response allHeaderFields];
    // Store status code
    responseStatusCode = [(NSHTTPURLResponse*)response statusCode];
    DLog(@"Response: %@", [response description]);
    completionHandler(NSURLSessionResponseAllow);
}

- (void) URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task didCompleteWithError:
    (NSError*)error
{
    if (delegate && [delegate respondsToSelector:@selector(requestDidFinish:withError:)]) {
        [delegate requestDidFinish:self withError:error];
    }
}

- (void) URLSession:(NSURLSession*)session didBecomeInvalidWithError:(NSError*)error
{
    if (delegate && [delegate respondsToSelector:@selector(requestDidFinish:withError:)]) {
        [delegate requestDidFinish:self withError:error];
    }
}

#pragma mark Authentication

- (void) URLSession:(NSURLSession*)session didReceiveChallenge:(NSURLAuthenticationChallenge*)
    challenge completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition disposition,
    NSURLCredential* credential))completionHandler;
{
    if (authenticationDelegate &&
            [authenticationDelegate respondsToSelector:@selector(request:didReceiveChallenge:completionHandler:
                                                                )]) {
        [authenticationDelegate request:self didReceiveChallenge:challenge completionHandler:
                                completionHandler];
    }
    else {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:
                                         challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    }
}


@end
