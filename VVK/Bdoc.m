//
//  Bdoc.m
//  VVK

#import "Bdoc.h"
#import <ZipZap/ZipZap.h>
#import <libxml/parser.h>
#import <libxml/c14n.h>
#import <libxml/xpathInternals.h>
#import <CommonCrypto/CommonDigest.h>
#import <openssl/evp.h>
#import <openssl/pem.h>
#import <openssl/bn.h>
#import <openssl/x509v3.h>


static NSString* const META_INF_DIR = @"META-INF/";
static NSString* const MIMETYPE_FILE = @"mimetype";
static NSString* const MIMETYPE_VALUE = @"application/vnd.etsi.asic-e+zip";
static NSString* const SIGNATURE_FILE_REGEX = @"^META-INF\\/(.*)signatures(.*)\\.xml$";
static NSString* const MANIFEST_FILE = @"META-INF/manifest.xml";
static xmlChar* const ATTR_URI = (xmlChar*)"URI";
static xmlChar* const ATTR_ALGORITHM = (xmlChar*)"Algorithm";
static xmlChar* const NUMBER_SIGN = (xmlChar*)"#";
static xmlChar* const SIGNATUREMETHOD_ECDSASHA256 = (xmlChar*)"http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256";
static xmlChar* const SIGNATUREMETHOD_RSASHA256 = (xmlChar*)"http://www.w3.org/2001/04/xmldsig-more#rsa-sha256";
static NSString* const XPATH_TEMPLATE_NODE_BY_ID = @"//*[@Id='%s']/descendant-or-self::node() | //*[@Id='%s']//@* | //*[@Id='%s']/namespace::*";
static xmlChar* const XPATH_REFERENCE = (xmlChar*)"//ds:Signature/ds:SignedInfo/ds:Reference";
static xmlChar* const XPATH_SIGNEDINFO = (xmlChar*)"//ds:SignedInfo/descendant-or-self::node() | //ds:SignedInfo//@* | //ds:SignedInfo/namespace::*";
static xmlChar* const XPATH_X509CERT = (xmlChar*)"//ds:X509Certificate";
static xmlChar* const XPATH_SIGNATUREVALUE = (xmlChar*)"//ds:SignatureValue/descendant-or-self::node() | //ds:SignatureValue//@* | //ds:SignatureValue/namespace::*";
static xmlChar* const XPATH_SIGNATUREMETHOD = (xmlChar*)"//ds:SignatureMethod";

@interface Bdoc()
-(BOOL)parseEntry:(ZZArchiveEntry*)entry;
-(BOOL)isMimeType:(NSString*)fileName;
-(BOOL)isSignatureFile:(NSString*)fileName;
-(BOOL)isVote:(NSString*)fileName;
-(BOOL)isManifest:(NSString*)fileName;
-(BOOL)validateMimeType:(NSData*)data;
-(NSString*)cleanVoteFileName:(NSString*)fileName;
-(xmlXPathContextPtr)createXPathContext:(xmlDocPtr)doc;
-(xmlNodeSetPtr)evalXPath:(xmlChar*)xpath ctx:(xmlXPathContextPtr)ctx;
-(NSData*)hash:(NSData*)data;
-(NSData*)c14nDoc:(xmlDocPtr)doc include:(xmlNodeSet*)nodes;
-(xmlChar*)createXPathStrForId:(xmlChar*)id;
-(BOOL)verifyDigests:(xmlDocPtr)doc references:(xmlNodeSetPtr)nodes xpathContext:(xmlXPathContextPtr)ctx;
-(int)asn1WrapSignature:(NSData*)sigData out:(unsigned char**)out;
-(xmlChar*)getSignatureMethod:(xmlXPathContextPtr)doc;
-(BOOL)verifySig:(xmlChar*)sig sigAlg:(xmlChar*)sigAlg key:(EVP_PKEY*)key data:(NSData*)data;
-(X509*)xmlCharToX509:(xmlChar*)data;
-(BOOL)isIssuedBySk:(X509*)cert_;
-(STACK_OF(X509)*)getSkCerts;
@end

@implementation Bdoc {
    NSData* signature;
    NSRegularExpression* voteFileRegex;
    NSMutableDictionary* rawVoteDict;
}

@synthesize votes;
@synthesize cert;
@synthesize signatureValue;
@synthesize issuer;

- (id)initWithData:(NSData *)data electionId:(NSString*)elId
{
    self = [super init];
    if (self) {
        NSString* voteFileRegexPattern = [NSString stringWithFormat:@"^%@\\.[^.]+\\.ballot$", elId];
        voteFileRegex = [NSRegularExpression regularExpressionWithPattern:voteFileRegexPattern options:0 error:nil];
        votes = [[NSMutableDictionary alloc] initWithCapacity:2];
        rawVoteDict = [[NSMutableDictionary alloc] initWithCapacity:2];
        NSError* err;
        ZZArchive* archive = [ZZArchive archiveWithData:data error:&err];
        if (archive == nil) {
            DLog("%@", [err localizedDescription]);
            return nil;
        }
        for (ZZArchiveEntry* entry in archive.entries)
        {
            if(![self parseEntry:entry]) {
                return nil;
            }
        }
    }
    return self;
    
}

-(BOOL)validateBdoc {
    BOOL ret = NO;
    xmlDocPtr doc = NULL;
    xmlNodeSetPtr referenceSet = NULL;
    xmlNodeSetPtr x509Set = NULL;
    xmlNodeSetPtr signatureSet = NULL;
    xmlXPathContextPtr context = NULL;
    xmlNodeSetPtr signedInfoSet = NULL;
    NSData* digestInput = NULL;
    EVP_PKEY* key = NULL;
    
    doc = xmlParseMemory([signature bytes], (int)[signature length]);
    if (doc == NULL) {
        DLog(@"Error parsing signature xml");
        goto end;
    }
    
    context = [self createXPathContext:doc];
    if (context == NULL) {
        goto end;
    }
    
    referenceSet = [self evalXPath:XPATH_REFERENCE ctx:context];
    if (referenceSet == NULL) {
        goto end;
    }
    
    if (![self verifyDigests:doc references:referenceSet xpathContext:context]) {
        goto end;
    }
    
    signedInfoSet = [self evalXPath:XPATH_SIGNEDINFO ctx:context];
    if (signedInfoSet == NULL) {
        goto end;
    }
    
    digestInput = [self c14nDoc:doc include:signedInfoSet];
    if (digestInput == NULL) {
        goto end;
    }

    x509Set = [self evalXPath:XPATH_X509CERT ctx:context];
    if (x509Set == NULL) {
        DLog(@"Couldn't find signer's X509 cert in signature file");
        goto end;
    }
    xmlChar* certPem = x509Set->nodeTab[0]->children[0].content;
    
    cert = [self xmlCharToX509:certPem];
    if (cert == NULL) {
        DLog(@"Couldn't read x509 cert");
        goto end;
    }
    
    if(![self isIssuedBySk:cert]) {
        goto end;
    }
    
    key = X509_get_pubkey(cert);
    if (key == NULL) {
        DLog("Couldn't extract key from x509 cert");
        goto end;
    }
    
    signatureSet = [self evalXPath:XPATH_SIGNATUREVALUE ctx:context];
    if (signatureSet == NULL) {
        DLog(@"Couldn't find signature value in signature file");
        goto end;
    }
    signatureValue = [self c14nDoc:doc include:signatureSet];
    
    xmlChar* sigValue = signatureSet->nodeTab[0]->children[0].content;
    if (![self verifySig:sigValue sigAlg:[self getSignatureMethod:context] key:key data:digestInput]) {
        DLog(@"Couldn't verify signature of bdoc");
        goto end;
    }
    ret = YES;
    
end:
    xmlXPathFreeNodeSet(referenceSet);
    xmlXPathFreeNodeSet(x509Set);
    xmlXPathFreeNodeSet(signatureSet);
    xmlXPathFreeNodeSet(signedInfoSet);
    xmlXPathFreeContext(context);
    xmlFreeDoc(doc);
    EVP_PKEY_free(key);

    return ret;
}

-(xmlXPathContextPtr)createXPathContext:(xmlDocPtr)doc
{
    xmlXPathContextPtr context = xmlXPathNewContext(doc);
    xmlXPathRegisterNs(context, BAD_CAST "asic", BAD_CAST "http://uri.etsi.org/02918/v1.2.1#");
    xmlXPathRegisterNs(context, BAD_CAST "ds", BAD_CAST "http://www.w3.org/2000/09/xmldsig#");
    xmlXPathRegisterNs(context, BAD_CAST "xades", BAD_CAST "http://uri.etsi.org/01903/v1.3.2#");
    
    if (context == NULL) {
        printf("Error in xmlXPathNewContext\n");
        return NULL;
    }
    return context;
}

-(xmlNodeSetPtr)evalXPath:(xmlChar *)xpath ctx:(xmlXPathContextPtr)ctx
{
    xmlXPathObjectPtr result = xmlXPathEvalExpression(xpath, ctx);
    if (result == NULL) {
        DLog("Error in xmlXPathEvalExpression\n");
        return NULL;
    }
    if(xmlXPathNodeSetIsEmpty(result->nodesetval)){
        xmlXPathFreeObject(result);
        DLog("XPath eval result empty\n");
        return NULL;
    }
    xmlNodeSetPtr ret = result->nodesetval;
    result->nodesetval = NULL;
    xmlXPathFreeObject(result);
    return ret;
}

-(NSData *) hash:(NSData *)data
{
    NSMutableData *out = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([data bytes], (int)[data length],  out.mutableBytes);
    return out;
}

-(NSData *)c14nDoc:(xmlDocPtr)doc include:(xmlNodeSet*)nodes
{
    xmlChar* buf = NULL;
    int ret = xmlC14NDocDumpMemory(doc, nodes, XML_C14N_1_1, NULL, 0, &buf);
    if (ret < 0) {
        DLog("Error in c14n");
        return NULL;
    }
    NSData* rett = [NSData dataWithBytes:buf length:ret];
    free(buf);
    return rett;
}

-(xmlChar *)createXPathStrForId:(xmlChar *)id
{
    NSString *label = [NSString stringWithFormat:XPATH_TEMPLATE_NODE_BY_ID, id, id, id];
    return (xmlChar*) [label cStringUsingEncoding:NSUTF8StringEncoding];
}

-(BOOL)verifyDigests:(xmlDocPtr)doc references:(xmlNodeSetPtr)nodes xpathContext:(xmlXPathContextPtr)ctx
{
    xmlChar* uri=NULL;
    NSData* digestInput=NULL;
    for (int i=0; i < nodes->nodeNr; i++) {
        // get hash value from last child's (DigestValue) content
        xmlNodePtr digestValueNode = xmlLastElementChild(nodes->nodeTab[i]);
        if (digestValueNode == NULL) {
            return NO;
        }
        NSString* hash = [NSString stringWithUTF8String:(char *)digestValueNode->children[0].content];
        hash = [hash stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        for (xmlAttrPtr attr = nodes->nodeTab[i]->properties; attr != NULL; attr = attr->next) {
            if (xmlStrEqual(attr->name, ATTR_URI)) {
                uri = attr->children->content;
                break;
            }
        }
        // check wether it is a file or xml element reference
        if (xmlStrncmp(uri, NUMBER_SIGN, 1) == 0) {
            uri++;
            xmlNodeSetPtr nodeSet = [self evalXPath:[self createXPathStrForId:uri] ctx:ctx];
            if (nodeSet == NULL) {
                return NO;
            }
            digestInput = [self c14nDoc:doc include:nodeSet];
            xmlXPathFreeNodeSet(nodeSet);
        } else {
            digestInput = rawVoteDict[[NSString stringWithUTF8String:(char *)uri]];
        }
        
        if (digestInput == NULL) {
            return NO;
        }
        NSString* computedHash = [[self hash:digestInput] base64EncodedStringWithOptions:0];
        if (![computedHash isEqualToString:hash]) {
            DLog(@"Hash missmatch: %s", uri);
            return NO;
        }
    }
    return YES;
}

-(int)asn1WrapSignature:(NSData *)sigData out:(unsigned char **)out {
    BIGNUM* num1 = BN_bin2bn([sigData bytes], (int)[sigData length] / 2, NULL);
    NSData* tmp = [sigData subdataWithRange:NSMakeRange([sigData length] / 2, [sigData length] / 2)];
    BIGNUM* num2 = BN_bin2bn([tmp bytes], (int)[tmp length], NULL);
    
    ASN1_INTEGER* int1 = BN_to_ASN1_INTEGER(num1, NULL);
    ASN1_INTEGER* int2 = BN_to_ASN1_INTEGER(num2, NULL);
    
    // trick to get asn1 integer object total length
    int i = i2d_ASN1_INTEGER(int1, NULL);
    i += i2d_ASN1_INTEGER(int2, NULL);
    int total = ASN1_object_size(1, i, V_ASN1_SEQUENCE);
    
    *out = malloc(total);
    if (out == NULL) {
        DLog("Malloc error");
        total = -1;
        goto end;
    }
    
    unsigned char* tmp2 = *out;
    ASN1_put_object(&tmp2, 1, i, V_ASN1_SEQUENCE, V_ASN1_UNIVERSAL);
    i2d_ASN1_INTEGER(int1, &tmp2);
    i2d_ASN1_INTEGER(int2, &tmp2);
    
end:
    BN_free(num1);
    BN_free(num2);
    ASN1_INTEGER_free(int1);
    ASN1_INTEGER_free(int2);
    return total;
}

-(xmlChar*)getSignatureMethod:(xmlXPathContextPtr)ctx
{
    xmlNodeSetPtr resultSet = [self evalXPath:XPATH_SIGNATUREMETHOD ctx:ctx];
    if (resultSet == NULL) {
        return NULL;
    }
    
    for (xmlAttrPtr attr = resultSet->nodeTab[0]->properties; attr != NULL; attr = attr->next) {
        if (xmlStrEqual(attr->name, ATTR_ALGORITHM)) {
            return attr->children->content;
        }
    }
    return NULL;
}

-(BOOL)parseEntry:(ZZArchiveEntry *)entry
{
    NSString* fileName = [entry fileName];
    NSData* data = [entry newDataWithError:nil];
    if ([self isMimeType:fileName]) {
        if (![self validateMimeType:data]) {
            DLog("Invalid mimetype value in bdoc");
            return NO;
        }
    } else if ([self isSignatureFile:fileName]) {
        signature = [entry newDataWithError:nil];
    } else if ([self isVote:fileName]) {
        [votes setObject:data forKey:[self cleanVoteFileName:fileName]];
        [rawVoteDict setObject:data forKey:fileName];
    } else if ([self isManifest:fileName]) {
    } else if (![fileName isEqualToString:@"META-INF/"]) {
        return NO;
    }
    return YES;
}

-(NSString *)cleanVoteFileName:(NSString *)fileName
{
    return [fileName componentsSeparatedByString:@"."][1];
}

-(BOOL)validateMimeType:(NSData *)data
{
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] isEqualToString:MIMETYPE_VALUE];
}

-(BOOL)isMimeType:(NSString *)fileName
{
    return [fileName isEqualToString:MIMETYPE_FILE];
}

-(BOOL)isSignatureFile:(NSString *)fileName
{
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:SIGNATURE_FILE_REGEX options:0 error:nil];
    return [regex numberOfMatchesInString:fileName options:0 range:NSMakeRange(0, [fileName length])] == 1;
    
}

-(BOOL)isVote:(NSString *)fileName
{
    return ![fileName hasPrefix:META_INF_DIR] &&
    ![self isMimeType:fileName] &&
    [voteFileRegex numberOfMatchesInString:fileName options:0 range:NSMakeRange(0, [fileName length])] == 1;
}

-(BOOL)isManifest:(NSString *)fileName
{
    return [fileName isEqualToString:MANIFEST_FILE];
}

-(BOOL)verifySig:(xmlChar*)sig sigAlg:(xmlChar*)sigAlg key:(EVP_PKEY*)key data:(NSData*)data
{
    BOOL ret = NO;
    NSData* tmp = [NSData dataWithBytes:sig length:xmlStrlen(sig)];
    NSData* sigDataRaw = [[NSData alloc] initWithBase64EncodedData:tmp options:NSDataBase64DecodingIgnoreUnknownCharacters];
    unsigned char* sigData = NULL;
    int total = 0;
    EVP_MD_CTX* md_ctx = EVP_MD_CTX_create();
    
    if (sigAlg == NULL) {
        DLog(@"No signature algorithm found in xml");
        goto end;
    } else if (xmlStrEqual(sigAlg, SIGNATUREMETHOD_ECDSASHA256)) {
        total = [self asn1WrapSignature:sigDataRaw out:&sigData];
        if (total == -1) {
            goto end;
        }
    } else if (xmlStrEqual(sigAlg, SIGNATUREMETHOD_RSASHA256)) {
        sigData = (unsigned char*)[sigDataRaw bytes];
        total = (int)[sigDataRaw length];
    } else {
        DLog(@"Unknown signature algorithm %s", sigAlg);
        goto end;
    }
    
    if (EVP_DigestVerifyInit(md_ctx, NULL, EVP_get_digestbyname("SHA256"), NULL, key) != 1) {
        DLog(@"Couldn't init digest verify");
        goto end;
    }
    if (EVP_DigestVerifyUpdate(md_ctx, (unsigned char*)[data bytes], [data length]) != 1) {
        DLog(@"Couldn't add digest input data to context");
        goto end;
    }
    int  res = EVP_DigestVerifyFinal(md_ctx, sigData, total);
    
    if (res <= 0) {
        DLog("Signature verification non-successful");
        goto end;
    }
    
    ret = YES;
end:
    EVP_MD_CTX_destroy(md_ctx);
    return ret;

}

-(X509*)xmlCharToX509:(xmlChar *)data
{
    NSData* tmp = [NSData dataWithBytes:data length:xmlStrlen(data)];
    
    NSData* der = [[NSData alloc] initWithBase64EncodedData:tmp options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    BIO* certBio = BIO_new_mem_buf([der bytes], (int)[der length]);
    if (certBio == NULL) {
        DLog(@"Couldn't init signing cert BIO");
        return NULL;
    }
    
    X509* cert_ = d2i_X509_bio(certBio, NULL);
    BIO_free(certBio);
    return cert_;
}

-(BOOL)isIssuedBySk:(X509 *)cert_
{
    STACK_OF(X509)* skCerts = [self getSkCerts];
    if (skCerts == NULL) {
        DLog("Couldn't init sk certstack");
        return NO;
    }
    BOOL issuerFound = NO;
    for (int i = 0; i < sk_X509_num(skCerts); i++) {
        X509 *ch = sk_X509_value(skCerts, i);
        int retval = X509_check_issued(ch, cert_);
        if (retval == X509_V_OK) {
            issuer = ch;
            sk_X509_delete(skCerts, i);
            issuerFound = YES;
            goto end;
        }
    }
    
end:
    sk_X509_free(skCerts);
    
    return issuerFound;
}

-(STACK_OF(X509)*)getSkCerts
{
    STACK_OF(X509)* ret = NULL;
    ret = sk_X509_new_null();
    if (ret == NULL) {
        return NULL;
    }

    for (NSString* path in @[
                             @"/ESTEID-SK_2011.pem.crt",
                             @"/ESTEID-SK_2015.pem.crt",
                             @"/esteid2018.pem.crt",
#ifdef DEBUG
                             @"/TEST_of_ESTEID-SK_2011.pem.crt",
                             @"/TEST_of_ESTEID-SK_2015.pem.crt",
                             @"/TEST_of_ESTEID2018.pem.crt",
#endif
                             ]) {
        X509* cert_ = [self getCert:path];
        if (cert_ == NULL) {
            sk_X509_free(ret);
            return NULL;
        }
        sk_X509_push(ret, cert_);
        DLog(@"Loaded SK certificate %@", path);
    }
    return ret;
}

-(X509*)getCert:(NSString *)path
{
    NSData* data = [[NSData alloc] initWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:path]];
    BIO* certBio = BIO_new_mem_buf([data bytes], (int)[data length]);
    if (certBio == NULL) {
        DLog(@"Couldn't create BIO");
        return NULL;
    }
    X509* cert_ = PEM_read_bio_X509_AUX(certBio, NULL, NULL, NULL);
    BIO_free(certBio);
    if (cert_ == NULL) {
        DLog(@"Couldn't load X509 cert");
        return NULL;
    }
    return cert_;
}
@end
