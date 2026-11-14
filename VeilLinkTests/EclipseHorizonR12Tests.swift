import XCTest
@testable import VeilLink

/// R12 tests require PR #209 trained kernel plus R12 opt-in overlay applied
/// on a dedicated Governor integration branch; not compiled on V29 main.
final class EclipseHorizonR12Tests: XCTestCase {
    func testDefaultKeepsFrozenCodexPolicyUnchanged() {
        XCTAssertFalse(VeilGomokuUnifiedSearch.Limits().r12HorizonQuiescence)
        XCTAssertEqual(VeilGomokuUnifiedSearch.Limits().r12MaxForcedBlocks, 2)
    }

    func testOwnWinOutranksEnemyFiveThreat() {
        var b = [UInt8](repeating: 0, count: 225)
        for at in [0, 1, 2, 3] { b[at] = 1 }
        for at in [60, 76, 92, 108] { b[at] = 2 }
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 1), .ownImmediateWin(4))
        XCTAssertEqual(EclipseHorizonQuiescenceR12.certifiedScore(
            .ownImmediateWin(4), mate: 10_000_000, ply: 1
        ), 9_999_998)
    }

    func testTwoDistinctOpponentFiveCompletionsProveShortLoss() {
        var b = [UInt8](repeating: 0, count: 225)
        for at in [109, 110, 111, 112] { b[at] = 2 }
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 1),
                       .opponentDoubleFive([108, 113]))
    }

    func testSingleForcedDefenseIsNotMistakenForMate() {
        var b = [UInt8](repeating: 0, count: 225)
        for at in [0, 1, 2, 3] { b[at] = 2 }
        b[5] = 1
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 1), .forcedBlock(4))
        XCTAssertNil(EclipseHorizonQuiescenceR12.certifiedScore(
            .forcedBlock(4), mate: 10_000_000, ply: 3
        ))
    }

    func testCodexArenaRealPreMovePositionMustBlock188() {
        // Frozen PR #209 final-compact-a, pair0, after 19 played stones.
        let history = [112,66,83,157,158,156,185,173,189,172,140,171,170,155,154,126,186,202,187]
        var b = [UInt8](repeating: 0, count: 225)
        for (i, move) in history.enumerated() { b[move] = UInt8(i % 2 + 1) }
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 2), .forcedBlock(188))
    }
}
