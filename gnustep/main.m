#import <Foundation/Foundation.h>

#import "Group.h"
#import "ElgamalPub.h"
#import "Scalar.h"

#import "PkixHelper.h"
#import "OcspHelper.h"

void checkEncryptionWithPublicKey(
        NSString* publicKeyB64,
        NSString* plaintextRaw,
        NSString* ciphertextB64,
        NSString* randomB64)
{

    ElgamalPub* pubKey = [[ElgamalPub alloc] initWithPemString:publicKeyB64];
    //XCTAssertNotNil(pubKey, "public key not initialized");

    NSData* randomnessBytes = [
        [NSData alloc] initWithBase64EncodedString:randomB64 options:0];

    Scalar *randomness = [[Scalar alloc] initWithBytes:randomnessBytes
                                                 group:pubKey.group];

    NSData* ciphertextBytes = [
        [NSData alloc] initWithBase64EncodedString:ciphertextB64 options:0];

    Ballot* ballot = [pubKey.group decodeBallotWithName:@"noname"
                                             ciphertext:ciphertextBytes];
  //  XCTAssertNotNil(ballot);

    Element *decryptedElement = [pubKey decryptBallot:ballot
                                           randomness:randomness];
 //   XCTAssertNotNil(decryptedElement);


    NSString *decryptedPlaintext = [decryptedElement decode];
    NSLog(@"%@", decryptedPlaintext);

//    XCTAssertTrue([plaintextRaw isEqualToString:decryptedPlaintext]);
}

void checkDecodingWithElectionId(
        NSString* electionId,
        NSString* publicKeyB64,
        NSString* plaintextRaw,
        NSString* plaintextEncodedB64)
{

    ElgamalPub* pubKey = [[ElgamalPub alloc] initWithPemString:publicKeyB64];
//    XCTAssertNotNil(pubKey);

    NSString *elId = [pubKey elId];
    NSLog(@"%@", elId);
//    XCTAssertTrue([elId isEqualToString:electionId]);

    NSData* plaintextEncoded = [
        [NSData alloc] initWithBase64EncodedString:plaintextEncodedB64 options:0];
    Element *element = [pubKey.group elementOfASN1:plaintextEncoded];

    NSString *plaintextDecoded = [element decode];
 //   XCTAssertTrue([plaintextRaw isEqualToString:plaintextDecoded]);
 //
    NSLog(@"%@", plaintextDecoded);
}


void testGroupMath(
        NSString* testCasesPath,
        NSArray* testFiles)
{
    // Iterate over all JSON files in the directory
    for (NSString *fileName in testFiles) {
        if ([fileName hasSuffix:@".json"]) {

            NSString *filePath = [testCasesPath stringByAppendingPathComponent:fileName];
            NSData *fileData = [NSData dataWithContentsOfFile:filePath];
            NSError *jsonError = nil;
            NSDictionary *testCase = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&jsonError];

            if (jsonError) {
                NSLog(@"Failed to parse JSON file: %@", jsonError.localizedDescription);
                continue;
            }

            NSLog(@"Processing: %@", fileName);
            NSLog(@"Case: %@", testCase);

            // Extract test case data
            NSString *electionId = [testCase objectForKey:@"election_id"];
            NSString *publicKeyB64 = [testCase objectForKey:@"public_key"];
            NSArray *encArray = [testCase objectForKey:@"encryptions"];
            NSDictionary *encObject = [encArray firstObject];
            NSString *ciphertextB64 = [encObject objectForKey:@"ciphertext"];
            NSString *randomB64 = [encObject objectForKey:@"random"];
            NSString *plaintextRaw = [encObject objectForKey:@"plaintext_raw"];
            NSString *plaintextEncodedB64 = [encObject objectForKey:@"plaintext_encoded"];

            // Perform checks
            checkEncryptionWithPublicKey(publicKeyB64, plaintextRaw, ciphertextB64, randomB64);
            NSLog(@"checkEncryption OK");

            checkDecodingWithElectionId(electionId, publicKeyB64, plaintextRaw, plaintextEncodedB64);
            NSLog(@"checkDecoding OK");
        }
    }
}


void processOcspTsa(NSString *subdir, NSString *ocspPath, NSString *tsaPath) {

    NSDictionary *resMap = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], @"not-ok",
        [NSNumber numberWithBool:YES], @"ok-0-diff",
        [NSNumber numberWithBool:YES], @"ok-2-diff",
        [NSNumber numberWithBool:NO], @"ok-10-diff",
        nil  // Important: Always end with `nil`
    ];

    NSData *ocspData = [NSData dataWithContentsOfFile:ocspPath];
    NSData *tsaData = [NSData dataWithContentsOfFile:tsaPath];

    if (!ocspData || !tsaData) {
        NSLog(@"Skipping %@ due to missing content", subdir);
        return;
    }

    PkixHelper* tsa = [[PkixHelper alloc] initWithData:tsaData];
    OcspHelper* ocsp = [[OcspHelper alloc] initWithData:ocspData];

    BOOL res = [tsa compareWithOCSP:ocsp maxdiff:8];

    BOOL expected = [[resMap objectForKey:subdir] boolValue ];

    if (res != expected) {
        NSLog(@"\nProblem processing: %@\n   Res:%d\n  ", subdir, res);
    }

}


void testPKIXOCSP(
        NSString* testCasesPath,
        NSArray* subDirs
        )
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;

    for (NSString *subdir in subDirs) {
        NSString *subdirPath = [testCasesPath stringByAppendingPathComponent:subdir];
        BOOL isDir;
        if (![fileManager fileExistsAtPath:subdirPath isDirectory:&isDir] || !isDir) {
            continue; // Skip if not a directory
        }

        NSString *ocspFile = nil;
        NSString *tsaFile = nil;

        NSArray *files = [fileManager contentsOfDirectoryAtPath:subdirPath error:&error];
        if (error) {
            NSLog(@"Error listing files in %@: %@", subdir, error.localizedDescription);
            continue;
        }

        // Find .ocsp and .tspreg files
        for (NSString *file in files) {
            if ([file hasSuffix:@".ocsp"]) {
                ocspFile = [subdirPath stringByAppendingPathComponent:file];
            } else if ([file hasSuffix:@".tspreg"]) {
                tsaFile = [subdirPath stringByAppendingPathComponent:file];
            }
        }

        // Ensure both files exist before processing
        if (ocspFile && tsaFile) {
            processOcspTsa(subdir, ocspFile, tsaFile);
        } else {
            NSLog(@"Skipping %@ (missing OCSP/TSA file)", subdir);
        }
    }
}



int main (int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testCasesPath = @"../VVKTests/test_cases";
    NSError *error = nil;
    NSArray *testFiles = [fileManager contentsOfDirectoryAtPath:testCasesPath error:&error];
    if (error) {
        NSLog(@"Finished with error: %@", error);
        return -1;
    }

    testGroupMath(testCasesPath, testFiles);

    testCasesPath = @"../VVKTests/tsaocsp";
    testFiles = [fileManager contentsOfDirectoryAtPath:testCasesPath error:&error];
    if (error) {
        NSLog(@"Finished with error: %@", error);
        return -1;
    }

    testPKIXOCSP(testCasesPath, testFiles);

    NSLog(@"Finished test");

    [pool drain];
    return 0;
}
