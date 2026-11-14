import XCTest
@testable import VeilLink

/// Runs only after Codex #209 and R12 are applied to an iOS integration branch.
final class EclipseHorizonR12Tests: XCTestCase {
    func testDefaultRollbackIsSafe() {
        XCTAssertFalse(VeilGomokuUnifiedSearch.Limits().r12HorizonQuiescence)
    }

    func testOpenFourIsAnExactImmediateWin() {
        var b = [UInt8](repeating: 0, count: 225)
        for at in [0, 1, 2, 3] { b[at] = 1 }
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 1), .ownImmediateWin(4))
        XCTAssertEqual(EclipseHorizonQuiescenceR12.certifiedScore(
            .ownImmediateWin(4), mate: 10_000_000, ply: 1
        ), 9_999_998)
    }

    func testTwoDistinctOpponentFiveCompletionsAreForcedLoss() {
        var b = [UInt8](repeating: 0, count: 225)
        for at in [109, 110, 111, 112] { b[at] = 2 }
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 1),
                       .opponentDoubleFive([108, 113]))
    }

    func testForcedBlockIsNotMistakenForProvenMate() {
        var b = [UInt8](repeating: 0, count: 225)
        for at in [0, 1, 2, 3] { b[at] = 2 }
        b[5] = 1
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 1), .forcedBlock(4))
        XCTAssertNil(EclipseHorizonQuiescenceR12.certifiedScore(
            .forcedBlock(4), mate: 10_000_000, ply: 3
        ))
    }

    func testRealCodexFrozenEvaluationPositionBlocks188() {
        // Source: Codex #209, final-compact-a, pair 0, after ply 18.
        let history = [112,66,83,157,158,156,185,173,189,172,140,171,170,155,154,126,186,202,187]
        var b = [UInt8](repeating: 0, count: 225)
        for (i, move) in history.enumerated() { b[move] = UInt8(i % 2 + 1) }
        XCTAssertEqual(EclipseHorizonQuiescenceR12.inspect(b, toMove: 2), .forcedBlock(188))
    }
}
