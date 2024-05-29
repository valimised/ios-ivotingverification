//
//  IVXVRequest.m
//  iVotingVerification

#import "IVXVRequest.h"

#import <openssl/ssl.h>
#import <openssl/x509v3.h>


int verify_callback(X509_STORE_CTX* server_ctx, void* param)
{
    STACK_OF(X509) *trust_ctx = (STACK_OF(X509)*)param;

    X509 *server_cert = X509_STORE_CTX_get0_cert(server_ctx);

    for (int i = 0; i < sk_X509_num(trust_ctx); i++) {

        X509* trusted_cert = sk_X509_value(trust_ctx, i);
        if (X509_V_OK == X509_check_issued(trusted_cert, server_cert)) {
            return 1;
        }

        if (0 == X509_cmp(server_cert, trusted_cert)) {
            return 1;
        }
    }
    return 0;
}

@implementation IVXVRequest {
    SSL_CTX* _ctx;
    BIO *_web;
    STACK_OF(X509) *_trusted;
    int _timeout;
}

- (id _Nonnull ) initWithCerts:(NSArray * _Nonnull)certStrArray;
{
    self = [super init];
    _ctx = NULL;
    _web = NULL;
    _trusted = NULL;
    _timeout = 0;

    _trusted = sk_X509_new_null();
    for (NSString *cert in certStrArray) {
        X509 *x509 = [self parseCertFromString:cert];
        if (x509) {
            sk_X509_push(_trusted, x509);
        }
    }

    return self;
}

- (void) dealloc
{
    if (_web != NULL) {
        BIO_free_all(_web);
    }

    if (_ctx != NULL) {
        SSL_CTX_free(_ctx);
    }

    if (_trusted != NULL) {
        sk_X509_pop_free(_trusted, X509_free);
    }
}

- (void) resetWithTimeout:(int)timeout
{
    if (_web != NULL) {
        BIO_free_all(_web);
        _web = NULL;
    }

    if (NULL != _ctx) {
        SSL_CTX_free(_ctx);
        _ctx = NULL;
    }
    _timeout = timeout;
}

- (void)sendHandshake:(NSString *_Nonnull)connStr
               sniStr:(NSString *_Nonnull)sniStr
           completion:(void (^_Nonnull)(NSError * _Nullable error))completion;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSError *error = nil;

        long res = 1;

        SSL *ssl = NULL;

        const SSL_METHOD* method = TLS_client_method();
        if (!(NULL != method)) {
            error = [NSError errorWithDomain:@"IVXV"
                                        code:401 userInfo:nil];
            goto error;
        }

        self->_ctx = SSL_CTX_new(method);
        if (!(self->_ctx != NULL)) {
            error = [NSError errorWithDomain:@"IVXV"
                                        code:402 userInfo:nil];
            goto error;
        }

        SSL_CTX_set_cert_verify_callback(self->_ctx, verify_callback, self->_trusted);
        SSL_CTX_set_verify(self->_ctx, SSL_VERIFY_PEER, NULL);
        SSL_CTX_set_options(self->_ctx, SSL_OP_NO_TICKET | SSL_OP_NO_COMPRESSION);
        SSL_CTX_set_min_proto_version(self->_ctx, TLS1_3_VERSION);
        SSL_CTX_set_max_proto_version(self->_ctx, TLS1_3_VERSION);

        self->_web = BIO_new_ssl_connect(self->_ctx);
        if (!(self->_web != NULL)) {
            error = [NSError errorWithDomain:@"IVXV"
                                        code:403 userInfo:nil];
            goto error;
        }

        const char* connCStr = [connStr UTF8String];
        res = BIO_set_conn_hostname(self->_web, connCStr);
        if (!(1 == res)) {
            error = [NSError errorWithDomain:@"IVXV"
                                        code:404 userInfo:nil];
            goto error;
        }

        BIO_get_ssl(self->_web, &ssl);
        if (!(ssl != NULL)) {
            error = [NSError errorWithDomain:@"IVXV"
                                        code:405 userInfo:nil];
            goto error;
        }

        const char* sniCStr = [sniStr UTF8String];
        res = SSL_set_tlsext_host_name(ssl, sniCStr);
        if (!(1 == res)) {
            error = [NSError errorWithDomain:@"IVXV"
                                        code:406 userInfo:nil];
            goto error;
        }

        res = BIO_do_connect_retry(self->_web, self->_timeout, 500);
        if (!(1 == res)) {
            DLog(@"conn %ld", res);
            error = [NSError errorWithDomain:@"IVXV"
                                        code:407 userInfo:nil];
            goto error;
        }

        X509* cert = SSL_get_peer_certificate(ssl);
        if (cert) {
            X509_free(cert);
        } else {
            error = [NSError errorWithDomain:@"IVXV"
                                        code:408 userInfo:nil];
            goto error;
        }

    error:

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(error);
            }
        });
    });
}

- (void)sendRequest:(NSData *_Nonnull)requestData
         completion:(void (^_Nonnull)(NSData * _Nullable responseData, NSError * _Nullable error))completion;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSError *error = nil;
        NSMutableData *responseData = [NSMutableData data];

        long res = 0;
        int timeout = 20;
        time_t max_time = time(NULL) + timeout;

        {
            const char *requestCStr = [requestData bytes];
            long dataLen = strlen(requestCStr);
            long left = dataLen;

            while (left > 0) {
                res = BIO_write(self->_web, requestCStr + (dataLen - left), (int)left);

                if (res > 0) {
                    left -= res;
                }
                else {
                    if (!BIO_should_retry(self->_web)) {
                        DLog(@"conn %ld", res);
                        error = [NSError errorWithDomain:@"IVXV"
                                                    code:410 userInfo:nil];
                        goto error;
                    }
                }
                res = BIO_wait(self->_web, max_time, 500);
                if (!(1 == res)) {
                    DLog(@"conn %ld", res);
                    error = [NSError errorWithDomain:@"IVXV"
                                                code:411 userInfo:nil];
                    goto error;
                }
            }
        }

        {
            char buff[2048] = {};

            do {
                res = BIO_wait(self->_web, max_time, 500);
                if (!(1 == res)) {
                    error = [NSError errorWithDomain:@"IVXV"
                                                code:412 userInfo:nil];
                    goto error;
                }

                res = BIO_read(self->_web, buff, sizeof(buff));

                if (res > 0) {
                    NSData *dataToAppend = [NSData dataWithBytes:buff length:res];
                    [responseData appendData:dataToAppend];
                }

            } while (res > 0 || BIO_should_retry(self->_web));
        }

    error:

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(responseData, error);
            }
        });
    });
}

- (X509 *) parseCertFromString:(NSString*)certStr
{
    // It is okay to trim all "\" and "n", because the string has to begin and end with "-".
    NSString* trimmed = [certStr stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]];
    NSArray* array = [trimmed componentsSeparatedByString:@"\n"];
    NSString* base64Str = [[array subarrayWithRange:NSMakeRange(1, [array count] - 2)] componentsJoinedByString:@""];
    NSData* certData = [[NSData alloc] initWithBase64EncodedString:base64Str options:0];

    const unsigned char *certBytes = (const unsigned char *)[certData bytes];
    BIO *certBio = BIO_new_mem_buf(certBytes, (int)[certData length]);
    if (certBio == NULL) {
        return NULL;
    }

    X509 *ret = d2i_X509_bio(certBio, NULL);
    BIO_free(certBio);
    return ret;
}

@end
