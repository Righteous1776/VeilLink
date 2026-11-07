import XCTest
@testable import VeilLink

final class VeilExportFileNameTests: XCTestCase {
    func testSameMomentProducesDistinctNamesForDifferentNonces() {
        let moment = Date(timeIntervalSince1970: 1_798_732_800.123)
        let first = VeilExportFileName.make(
            prefix: "VeilLink-",
            suffix: ".zip",
            date: moment,
            nonce: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        )
        let second = VeilExportFileName.make(
            prefix: "VeilLink-",
            suffix: ".zip",
            date: moment,
            nonce: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasPrefix("VeilLink-"))
        XCTAssertTrue(first.hasSuffix(".zip"))
        XCTAssertTrue(second.hasPrefix("VeilLink-"))
        XCTAssertTrue(second.hasSuffix(".zip"))
    }

    func testBoardLearningNameKeepsCleanupContract() {
        let name = VeilExportFileName.make(
            prefix: "VeilLink-GomokuLearning-",
            suffix: ".vltrain.json",
            date: Date(timeIntervalSince1970: 1_798_732_800),
            nonce: UUID(uuidString: "ABCDEF12-0000-0000-0000-000000000000")!
        )

        XCTAssertTrue(name.hasPrefix("VeilLink-GomokuLearning-"))
        XCTAssertTrue(name.hasSuffix(".vltrain.json"))
        XCTAssertTrue(name.contains("ABCDEF12"))
    }
}
