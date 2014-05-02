//
//  Request.m
//  iVotingVerification
//
//  Created by Eigen Lenk on 1/28/14.
//  Copyright (c) 2014 Applaud OÜ. All rights reserved.
//

#import "Request.h"

#import "NSString+URLEncoding.h"

@implementation Request

#pragma mark - Properties

@synthesize request;
@synthesize responseData;
@synthesize connection;
@synthesize responseHeaders;
@synthesize responseStatusCode;
@synthesize validHost;
@synthesize delegate;
@synthesize authenticationDelegate;


#pragma mark - Initialization

- (id)initWithHost:(NSString *)host path:(NSString *)path
{
    return [self initWithURL:[NSURL URLWithString:[host stringByAppendingString:path]] options:nil];
}

- (id)initWithURL:(NSURL *)url
{
    return [self initWithURL:url options:nil];
}


- (id)initWithURL:(NSURL *)url options:(NSDictionary *)options
{
    self = [super init];
    
    if (self)
    {
        responseData = [NSMutableData data];
        request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
        validHost = nil;
        
        if ([options[@"requestType"] isEqualToString:@"POST"])
        {
            NSString * urlEncodedPostData = [NSString URLEncodedStringWithDictionary:options[kRequestPOST]];

            postData = [urlEncodedPostData dataUsingEncoding:NSUTF8StringEncoding];
            httpBodyInputStream = [NSInputStream inputStreamWithData:postData];
            
            [request setHTTPMethod:@"POST"];
            [request setHTTPBodyStream:httpBodyInputStream];
            [request addValue:[NSString stringWithFormat:@"%d", postData.length] forHTTPHeaderField:@"Content-Length"];
            [request addValue:@"close" forHTTPHeaderField:@"Connection"];
        }
    }
    
    return self;
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void)dealloc
{
    request = nil;
    responseData = nil;
    connection = nil;
    responseHeaders = nil;
    delegate = nil;
    authenticationDelegate = nil;
    postData = nil;
    httpBodyInputStream = nil;
    validHost = nil;
}


#pragma mark - Public methods

- (void)start
{
    connection = [NSURLConnection connectionWithRequest:request delegate:self];
    
    [connection start];
}


#pragma mark - NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)receivedData
{
    [responseData appendData:receivedData];
}

- (void)connection:(NSURLConnection *)_connection didReceiveResponse:(NSURLResponse *)response
{
    // Store response headers
    responseHeaders = [(NSHTTPURLResponse*)response allHeaderFields];
 
    // Store status code
    responseStatusCode = [(NSHTTPURLResponse*)response statusCode];
    
    DLog(@"Response: %@", [response description]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (delegate && [delegate respondsToSelector:@selector(requestDidFinish:)])
    {
        [delegate requestDidFinish:self];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    DLog(@"Connection error: %@", error);
    
    if (delegate && [delegate respondsToSelector:@selector(request:didFailWithError:)])
    {
        [delegate request:self didFailWithError:error];
    }
}


#pragma mark Authentication

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (authenticationDelegate && [authenticationDelegate respondsToSelector:@selector(request:didReceiveAuthenticationChallenge:)])
    {
        [authenticationDelegate request:self didReceiveAuthenticationChallenge:challenge];
    }
    else
    {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    if (authenticationDelegate && [authenticationDelegate respondsToSelector:@selector(request:canAuthenticateAgainstProtectionSpace:)])
    {
        return [authenticationDelegate request:self canAuthenticateAgainstProtectionSpace:protectionSpace];
    }
    else
    {
        return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
    }
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    DLog(@"%@", [[Config sharedInstance] errorMessageForKey:@"bad_verification_message"] );
}

@end
