import XCTest
@testable import VeilLink

final class VeilMonogatariRangeTests: XCTestCase {
    func testFullBodyAndSingleByteRange() {
        XCTAssertEqual(VeilNovelRangeParser.resolve(nil, fileLength: 100)?.count, 100)
        XCTAssertEqual(VeilNovelRangeParser.resolve("bytes=0-0", fileLength: 100)?.contentRange, "bytes 0-0/100")
        XCTAssertEqual(VeilNovelRangeParser.resolve("bytes=13-", fileLength: 100)?.contentRange, "bytes 13-99/100")
        XCTAssertEqual(VeilNovelRangeParser.resolve("bytes=90-300", fileLength: 100)?.contentRange, "bytes 90-99/100")
        XCTAssertEqual(VeilNovelRangeParser.resolve("bytes=99-99", fileLength: 100)?.count, 1)
    }

    func testSuffixRanges() {
        XCTAssertEqual(VeilNovelRangeParser.resolve("bytes=-10", fileLength: 100)?.contentRange, "bytes 90-99/100")
        XCTAssertEqual(VeilNovelRangeParser.resolve("bytes=-999", fileLength: 100)?.count, 100)
    }

    func testRejectMalformedAndUnsatisfiableRanges() {
        ["bytes=100-", "bytes=12-11", "bytes=1-2,3-4", "bytes=1-xyz",
         "bytes=18446744073709551616-", "bytes=-0", "BYTES=1-5"].forEach { header in
            XCTAssertNil(VeilNovelRangeParser.resolve(header, fileLength: 100), header)
        }
        XCTAssertNil(VeilNovelRangeParser.resolve(nil, fileLength: 0))
    }
}
