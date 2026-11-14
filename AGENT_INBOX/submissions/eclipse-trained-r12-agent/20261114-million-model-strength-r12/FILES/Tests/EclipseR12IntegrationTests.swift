import XCTest
@testable import VeilLink

/// Native iOS tests to run ONLY after Codex #209 and R12 are integrated.
/// The two default-off switches must be tested for frozen R10 compatibility.
final class EclipseR12IntegrationTests: XCTestCase {
    func testMemoKeyIncludesBoardTurnAndCell() {
        var memo = EclipseR12OrderingMemo(capacity: 1)
        memo.put(hash: 100, side: 1, index: 112, value: 70)
        XCTAssertEqual(memo.get(hash: 100, side: 1, index: 112), 70)
        XCTAssertNil(memo.get(hash: 101, side: 1, index: 112))
        XCTAssertNil(memo.get(hash: 100, side: 2, index: 112))
        XCTAssertNil(memo.get(hash: 100, side: 1, index: 113))
        XCTAssertNil(memo.get(hash: 100, side: 3, index: 112))
        memo.put(hash: 200, side: 2, index: 88, value: -90)
        XCTAssertEqual(memo.get(hash: 200, side: 2, index: 88), -90)
        XCTAssertNil(memo.get(hash: 100, side: 1, index: 112))
    }

    func testLeavesRecognizeExactForcedBlockAndMultipleFiveThreats() {
        var b = [UInt8](repeating: 0, count: 225)
        for i in [109, 110, 111, 112] { b[i] = 2 }
        XCTAssertEqual(EclipseR12LeafThreats.inspect(cells: b, side: 1), .forcedBlock(113))
        b[97] = 1
        XCTAssertEqual(EclipseR12LeafThreats.inspect(cells: b, side: 1), .forcedBlock(113))
        b[113] = 1
        XCTAssertEqual(EclipseR12LeafThreats.inspect(cells: b, side: 1), .quiet)
    }

    func testFlagsAreOffForLegacyFrozenR10Behavior() {
        let limits = VeilGomokuUnifiedSearch.Limits()
        XCTAssertFalse(limits.r12OrderingMemoEnabled)
        XCTAssertEqual(limits.r12LeafThreatExtension, 0)
    }
}
