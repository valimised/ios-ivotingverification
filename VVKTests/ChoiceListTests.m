//
//  BallotASNTests.m
//

#import <XCTest/XCTest.h>

#import "ChoiceList.h"

NSString *choiceListEncoded = @"ew0KIkVyYWtvbmQgQSI6IHsNCiAgICAgICAgICAgICAgICAiMDAwMC4xMDEiOiAiSGVybWVzIiwNCiAgICAgICAgICAgICAgICAiMDAwMC4xMDIiOiAiSGVwaGFlc3R1cyIsDQogICAgICAgICAgICAgICAgIjAwMDAuMTAzIjogIkFyZXMiLA0KICAgICAgICAgICAgICAgICIwMDAwLjEwNCI6ICJDcm9ub3MiDQogICAgICAgICAgICB9LA0KIkVyYWtvbmQgQiI6IHsNCiAgICAgICAgICAgICAgICAiMDAwMC4xMDUiOiAiSnV1ZGl0IiwNCiAgICAgICAgICAgICAgICAiMDAwMC4xMDYiOiAiT2xvdmVybmVzIiwNCiAgICAgICAgICAgICAgICAiMDAwMC4xMDciOiAiRGVzZGVtb25hIiwNCiAgICAgICAgICAgICAgICAiMDAwMC4xMDgiOiAiU2lzeXBob3MiDQp9DQp9DQo=";


@interface ChoiceListTests : XCTestCase

@end

@implementation ChoiceListTests

- (void)setUp {
}

- (void)tearDown {
}

- (bool) doTestCandidateList:(ChoiceList*)choiceList
                   candidate:(NSString*)candidate
                       party:(NSString*)party
                        name:(NSString*)name
{
    Candidate *c1 = [choiceList findCandidate:candidate];

    if (!c1) {
        return NO;
    }

    if (![c1.number isEqualToString:candidate]) {
        return NO;
    }

    if (![c1.name isEqualToString:name]) {
        return NO;
    }

    if (![c1.party isEqualToString:party]) {
        return NO;
    }

    return YES;
}


- (void)testChoiceList {

    ChoiceList *choiceList = [[ChoiceList alloc] initWithBase64:choiceListEncoded];
    XCTAssertNotNil(choiceList, "data must decode");

    bool res;

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.101" party:@"Erakond A" name:@"Hermes"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.102" party:@"Erakond A" name:@"Hephaestus"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.103" party:@"Erakond A" name:@"Ares"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.104" party:@"Erakond A" name:@"Cronos"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.105" party:@"Erakond B" name:@"Juudit"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.106" party:@"Erakond B" name:@"Olovernes"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.107" party:@"Erakond B" name:@"Desdemona"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.108" party:@"Erakond B" name:@"Sisyphos"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList
                          candidate:@"0000.109" party:@"Erakond C" name:@"Athena"];
    XCTAssertFalse(res);
}

@end
