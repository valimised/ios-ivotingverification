#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>
#import "Ballot.h"
#import "ElgamalPub.h"
#import "Scalar.h"
#import "Group.h"


@interface DecryptionTest : XCTestCase
@end

@implementation DecryptionTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testUsingMultipleJsonFixtures {

    self.continueAfterFailure = FALSE;

    // Get the test cases directory (you need to ensure the JSON files are bundled with your app for testing)
    NSString *testCasesPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_cases" ofType:nil];
    NSError *error = nil;
    NSArray *testFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:testCasesPath error:&error];

    // Check for errors
    if (error) {
        XCTFail(@"Failed to read directory: %@", error.localizedDescription);
        return;
    }

    // Iterate over all JSON files in the directory
    for (NSString *fileName in testFiles) {
        if ([fileName hasSuffix:@".json"]) {

            NSString *filePath = [testCasesPath stringByAppendingPathComponent:fileName];
            NSData *fileData = [NSData dataWithContentsOfFile:filePath];
            NSError *jsonError = nil;
            NSDictionary *testCase = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&jsonError];

            if (jsonError) {
                XCTFail(@"Failed to parse JSON file: %@", jsonError.localizedDescription);
                continue;
            }

            NSLog(@"Processing: %@", fileName);

            // Extract test case data
            NSString *electionId = testCase[@"election_id"];
            NSString *publicKeyB64 = testCase[@"public_key"];
            NSArray *encArray = testCase[@"encryptions"];
            NSDictionary *encObject = [encArray firstObject];
            NSString *ciphertextB64 = encObject[@"ciphertext"];
            NSString *randomB64 = encObject[@"random"];
            NSString *plaintextRaw = encObject[@"plaintext_raw"];
            NSString *plaintextEncodedB64 = encObject[@"plaintext_encoded"];

            // Perform checks
            [self checkEncryptionWithPublicKey:publicKeyB64 plaintextRaw:plaintextRaw ciphertext:ciphertextB64 randomB64:randomB64];
            NSLog(@"checkEncryption OK");

            [self checkDecodingWithElectionId:electionId publicKey:publicKeyB64 plaintextRaw:plaintextRaw plaintextEncodedB64:plaintextEncodedB64];
            NSLog(@"checkDecoding OK");
        }
    }

    NSLog(@"Finished test");
}

- (void)checkEncryptionWithPublicKey:(NSString *)publicKeyB64
                        plaintextRaw:(NSString *)plaintextRaw
                          ciphertext:(NSString *)ciphertextB64
                           randomB64:(NSString *)randomB64 {

    ElgamalPub* pubKey = [[ElgamalPub alloc] initWithPemString:publicKeyB64];
    XCTAssertNotNil(pubKey, "public key not initialized");

    NSData* randomnessBytes = [
        [NSData alloc] initWithBase64EncodedString:randomB64 options:0];

    Scalar *randomness = [[Scalar alloc] initWithBytes:randomnessBytes
                                                 group:pubKey.group];

    NSData* ciphertextBytes = [
        [NSData alloc] initWithBase64EncodedString:ciphertextB64 options:0];

    Ballot* ballot = [pubKey.group decodeBallotWithName:@"noname"
                                             ciphertext:ciphertextBytes];
    XCTAssertNotNil(ballot);

    Element *decryptedElement = [pubKey decryptBallot:ballot
                                           randomness:randomness];
    XCTAssertNotNil(decryptedElement);


    NSString *decryptedPlaintext = [decryptedElement decode];

    XCTAssertTrue([plaintextRaw isEqualToString:decryptedPlaintext]);
}

- (void)checkDecodingWithElectionId:(NSString *)electionId
                          publicKey:(NSString *)publicKeyB64
                       plaintextRaw:(NSString *)plaintextRaw
                plaintextEncodedB64:(NSString *)plaintextEncodedB64 {

    ElgamalPub* pubKey = [[ElgamalPub alloc] initWithPemString:publicKeyB64];
    XCTAssertNotNil(pubKey);

    NSString *elId = [pubKey elId];
    XCTAssertTrue([elId isEqualToString:electionId]);

    NSData* plaintextEncoded = [
        [NSData alloc] initWithBase64EncodedString:plaintextEncodedB64 options:0];
    Element *element = [pubKey.group elementOfASN1:plaintextEncoded];

    NSString *plaintextDecoded = [element decode];
    XCTAssertTrue([plaintextRaw isEqualToString:plaintextDecoded]);
}

@end
