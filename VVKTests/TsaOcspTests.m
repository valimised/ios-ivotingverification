#import <XCTest/XCTest.h>
#import "OcspHelper.h"
#import "Pkixhelper.h"

@interface TsaOcspTests : XCTestCase

@end

@implementation TsaOcspTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}


- (void)testTsaOcspWithMultipleScenarios {
    NSError *error = nil;
    NSString *testDirectoryPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"tsaocsp" ofType:nil];
    NSArray *subDirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:testDirectoryPath error:&error];

    if (error) {
        XCTFail(@"Failed to read directory: %@", error.localizedDescription);
        return;
    }

    testPKIXOCSP(testDirectoryPath, subDirs);
}

void testPKIXOCSP(NSString* testCasesPath,NSArray* subDirs)
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

void processOcspTsa(NSString *subdir, NSString *ocspPath, NSString *tsaPath) {

    NSDictionary *resMap = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], @"not-ok", // ocsp before tsa
        [NSNumber numberWithBool:YES], @"ok-0-diff", // tsa in the same sec as ocsp
        [NSNumber numberWithBool:YES], @"ok-2-diff", // tsa 2 sec before ocsp
        [NSNumber numberWithBool:NO], @"ok-10-diff", // tsa 10 sec before ocsp
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

    XCTAssertTrue(res == expected, @"%@: expected: %d, but got: %d", subdir, expected, res);
}

@end
