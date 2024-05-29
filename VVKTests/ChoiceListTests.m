//
//  BallotASNTests.m
//

#import <XCTest/XCTest.h>

#import "ChoiceList.h"

NSString *choiceListEncoded = @"ew0KICAgICAgICAgICAgIktlbGxlIHZhbGlkIEV1cm9vcGEgUGFybGFtZW50aT8iOiB7DQogICAgICAgICAgICAgICAgIjAwMDAuMTAxIjogIkhlcm1lcyIsDQogICAgICAgICAgICAgICAgIjAwMDAuMTAyIjogIkhlcGhhZXN0dXMiLA0KICAgICAgICAgICAgICAgICIwMDAwLjEwMyI6ICJBcmVzIiwNCiAgICAgICAgICAgICAgICAiMDAwMC4xMDQiOiAiQ3Jvbm9zIg0KICAgICAgICAgICAgfQ0KICAgICAgICB9";


@interface ChoiceListTests : XCTestCase

@end

@implementation ChoiceListTests

- (void)setUp {
}

- (void)tearDown {
}

- (bool) doTestCandidateList:(ChoiceList*)choiceList candidate:(NSString*)candidate
{
    Candidate *c1 = [[Candidate alloc] initWithComponents:[candidate componentsSeparatedByString:@";"]];

    return [choiceList isValidCandidate:c1];
}


- (void)testChoiceList {

    ChoiceList *choiceList = [[ChoiceList alloc] initWithBase64:choiceListEncoded];
    XCTAssertNotNil(choiceList, "data must decode");

    bool res;

    res = [self doTestCandidateList:choiceList candidate:@"0000.101;Kelle valid Euroopa Parlamenti?;Hermes"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList candidate:@"0000.102;Kelle valid Euroopa Parlamenti?;Hephaestus"];
    XCTAssertTrue(res);

    res = [self doTestCandidateList:choiceList candidate:@"0000.102;Kelle valid Euroopa Parlamenti?;Hermes"];
    XCTAssertFalse(res);

    res = [self doTestCandidateList:choiceList candidate:@"0000.101;Kelle valid Euroopa Parlamenti?;Dionysus "];
    XCTAssertFalse(res);

    res = [self doTestCandidateList:choiceList candidate:@"1337.101;Kelle valid Euroopa Parlamenti?;Hermes"];
    XCTAssertFalse(res);

    res = [self doTestCandidateList:choiceList candidate:@"0000.666;Kelle valid Euroopa Parlamenti?;Hermes"];
    XCTAssertFalse(res);

    res = [self doTestCandidateList:choiceList candidate:@"0000.101;Kelle valid Olümpose mäele?;Hermes"];
    XCTAssertFalse(res);

    res = [self doTestCandidateList:choiceList candidate:@"0000.101;Kelle valid Euroopa Parlamenti?;HermeS"];
    XCTAssertFalse(res);

    res = [self doTestCandidateList:choiceList candidate:@"0000.101;Kelle valid Euroopa parlamenti?;Hermes"];
    XCTAssertFalse(res);
}

@end
