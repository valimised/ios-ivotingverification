//
//  BallotASNTests.m
//

#import <XCTest/XCTest.h>

#import "ElgamalPub.h"
#import "GroupModP.h"

NSString *correctVoteEncoded = @"MIIDGjALBgkrBgEEAZdVAgEwggMJAoIBgFsd8EkKe2dSHgjIzoM5a3Wk+XlpwmGygFOD31eVSSg8\n"
        "xMiZ8u4e1RL2pYoF/EmpxiR7d9veMb3cNaMr65WnM6iGIOklPHMvBS2VsepXK90wWUbpNTk1y5bS\n"
        "bnEVOYEc089es4hb6OWjE7SQzgYONXn2c/wKeNuIasrew99m2luCSNF42Bc3AUQNroF5nlEfSjQ6\n"
        "BNojHaeNmcitEFNn2zBMAcnWJ09ZY9+LYfolLw9FXuFG9iXknmVDoA72Hyw5FQqGENmxylDiFZEp\n"
        "2Aa17x7AIt5/RzcJiC5TouzO8leyji811Nk/7levexOCY0iO7MoPESyoUew97CIT9XELuqaa0BWK\n"
        "6OU76TzvLfOw1o5P1WbOImRAqNDA70aXw4syoiKLkL+tITceXOdztGVf9amNYv+7UdI3sLwgvXJu\n"
        "L7H1JhUFtIwFvIfGtjBfkz9j0p7NE6uq+4yr+eHP4VTBBA9HOFq6taWb7BopLsZb9f5oB+4L7uK4\n"
        "EfcKspPhO/Xp2wKCAYEA/xcMToX3/C2JiOiAq2Vh8PMGZ0P6PpMRarDFdwSULncjcfbBUC3eaSfy\n"
        "tVvcceZfI1eSaXl3RtBme47CpSb4cRWdwTG2QyijuutD6R36Q5ulO1sjInukZbopU/4uAfMrSZDH\n"
        "0nqO1QTVjLUfYelft7f3GrI8D0+g9ItikRn+Hlu1XQaJAgB0yC9joYu47x99wD1UamPCJgm9TEgY\n"
        "UFtgi2/fpjc6X1ljq3/2bzj7pqS9WnZ0hQypSdrTG5iq4EaxbI3aMen69EDJb69SNx4dtYleUvSC\n"
        "WuuV+5ZIH38NRKwG3jRz/WURL+W3oIADATBgbhtchtTPkoPYiJm01cZNpMThuOnG3uuQYd6rZCxo\n"
        "3spu4IFoUXUQ6s2iZtfzyJ2Mj8uHNtOgpZseqU5daMi8TbnLoHMRLO7nFXCIpTDvzohqn9k4/kvt\n"
        "DcSeFryXjC1qAXKmxhxeRyIIAPcfVBLiPjjFNYb5zeA1vgwvRACOcfl5Vwtryp1hvPCu3Z3SGqGH";

NSString *incorrectVoteEncoded = @"MIIENzCCAicGCSsGAQQBl1UCATCCAhgCggEBAPWeqWgtFnkimfjVE7OMvC5IZbhvPrWSqQEHtA01\n"
        "jCOINS3Xi4yvnNIuKJa4Q+laXWkeySiSWMyDMlRwriDKui4zV8mTx5N534rLb34vz+mxq7laOkoM\n"
        "76YJ6QULaM7ufHrBaRyXod2pi13Sd81Eh5YAouZNQlbQiqEzWqe8UO461K4jJio8JtFA//6DDGfw\n"
        "2v/Z8Mk9742uDBez6h/48AWKtozezA0SufK8RdpZKJx0vxWToTxtiO38PZNR2t9kl+oR5GLw37sH\n"
        "W5DFxV4s189p2GaUffogsl92pz3bMyoPGuQR45dPI0GKYwMBBdgP6omRH5nJkXlp9BwzAVOQifcC\n"
        "ggEBAJ7nY0lp16PGi6Z5cvQpw/LFTbQBU8zIrM/UH0TDfvuyHf0et9LiALh2vXnidRspwmRGma9X\n"
        "tFRQFV+q8z+Z4i45Fmfo/OEXRVd0YA7ZtVIhZF9/cOesn/L0AirTVR3VndnLYNvh7yFnSVrrvvWQ\n"
        "5/9HEIrJBDCiDZ8zVANew5pe027EdHXDRUBWNSO4AYtKNdx0FufS1thoJr7ppVJ/xVKvbexqWgiR\n"
        "Yy07RDwheEfQE7khgA27EbXb1gXeYczKbTkgaohR42YubFAXodRotZPk6rFV7H/Yj+IKWLBRHg7p\n"
        "MsSO0rTcHmbDD1ykMjJQzdy39Fqii3L0K+lSLEpLpLMbDERJUkUtU1RSQUlUUzCCAggCggEAbvx4\n"
        "7ltvLPSeQcZMQN/GwNZaeE2GresfIjd9F6hP2PX5eNjYEmzdzcA5mryd2UMq4DSvQi6e30fWGq8O\n"
        "TeeDgg3RycA5JzR+s+DdvttultpEESY7iIW+TxJ5pKvAxY7lv1KWgTLL7uCRc/nfqjwybKtNGN1q\n"
        "0PZCMz36BcGohG6ibIME6Vwf2t0SVl7x5JZ1jfF3YICrb2nlRwh6qz9nCNc+p1rdfpXCv+NOE9Rw\n"
        "dQG2rO+UEgN+2Qo7b6m8CtHbj5dlKrACAazmuyeEVizTLJ8q37ihmOoUP8eJbKB+qAGgX8rg0z35\n"
        "6LPfh9WFIj7dtae40reMp4zCx+BCcM6KOwKCAQARX2rGzgD9LxzytJEjSMsnvJzhYH/qdZntWJQP\n"
        "8vP9yzykTzyWyhtrjEjTBUJjbameukzvkxT1pfHSzQJdC8SJImP9K/u/6ANQIyWlzEpw399ryOXy\n"
        "n/7sGOsc3j3dmulrwkdQ+1kflSxS4ijdQ1QTMU6kpWDZUTY9sW4ieQLOLrJxZNrWKwW+WigYJsFN\n"
        "wPE6pI+BELVboQAkcHZmCVkOBGwASWAm7Th669xxalX+Z6nhcPjRh4sGvN8lDJ6bsMlkd3bBahUa\n"
        "6CV6bY7EugloOM5ENfNKhxLSYMDRv7meGVBIol+O6df8j3mSw0ixCvE+t6jwDPbuCAk2wzIV740l";

@interface BallotASNTests : XCTestCase

@end

@implementation BallotASNTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testCorrectASN {

    NSData *data = [[NSData alloc] initWithBase64EncodedString:correctVoteEncoded options:NSDataBase64DecodingIgnoreUnknownCharacters];
    XCTAssertNotNil(data, "data must exist");
    ModPGroup *group = [[ModPGroup alloc] init];
    NSString *questionDesc = @"test";
    Ballot* ballot = [group decodeBallotWithName:questionDesc ciphertext:data];
    XCTAssertNotNil(ballot, "ballot must decode");

}

- (void)testIncorrectASN {

    NSData *data = [[NSData alloc] initWithBase64EncodedString:incorrectVoteEncoded options:NSDataBase64DecodingIgnoreUnknownCharacters];
    XCTAssertNotNil(data, "data must exist");
    ModPGroup *group = [[ModPGroup alloc] init];
    NSString *questionDesc = @"test";
    Ballot* ballot = [group decodeBallotWithName:questionDesc ciphertext:data];
    XCTAssertNil(ballot, "ballot must not decode");
}

@end
