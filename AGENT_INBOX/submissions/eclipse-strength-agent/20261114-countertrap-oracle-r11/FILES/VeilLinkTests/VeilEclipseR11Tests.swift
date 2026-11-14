import XCTest
@testable import VeilLink

/// Proposed native-target tests; execute only after Governor integrates the
/// R10 + R11 source files onto an iOS integration branch.
final class VeilEclipseR11Tests: XCTestCase {
    private func position(black: [Int], white: [Int]) -> VeilEclipseStrategicPlannerR10.Position {
        var board = [UInt8](repeating: 0, count: 225)
        for at in black { board[at] = 1 }
        for at in white { board[at] = 2 }
        return VeilEclipseStrategicPlannerR10.Position(cells: board, toMove: 1)!
    }

    func testR11PrefersProvablySafeRootOverOpponentForkTrap() throws {
        let state = position(black: [0,2,4,6,8,10], white: [109,110,111,67,82,97])
        let result = try XCTUnwrap(VeilEclipseTacticalOracleR11.audit(
            position: state, vettedRoots: [52,108,112,140],
            deadline: Date.timeIntervalSinceReferenceDate + 2
        ))
        XCTAssertEqual(result.filteredRoots, [112])
        XCTAssertEqual(result.reports.filter(\.isTacticallyLosing).count, 3)
        XCTAssertFalse(result.reports.first(where: { $0.index == 112 })!.isProvenWinning)
    }

    func testR11PreservesSelfWinningForkCertificate() throws {
        let state = position(black: [109,110,111,67,82,97], white: [0,2,4,6,8,10])
        let result = try XCTUnwrap(VeilEclipseTacticalOracleR11.audit(
            position: state, vettedRoots: [52,140,150],
            deadline: Date.timeIntervalSinceReferenceDate + 2
        ))
        XCTAssertEqual(result.certifiedWins, [52])
        XCTAssertEqual(result.reports.first?.classification, .forcedTwoTurnWin)
    }

    func testR11TimeoutAndShortWorkloadCannotFilterRoots() {
        let state = position(black: [0,2,4,6,8,10], white: [109,110,111,67,82,97])
        XCTAssertNil(VeilEclipseTacticalOracleR11.audit(
            position: state, vettedRoots: [52,112],
            deadline: Date.timeIntervalSinceReferenceDate - 1
        ))
        XCTAssertNil(VeilEclipseTacticalOracleR11.audit(
            position: state, vettedRoots: [52,112],
            deadline: Date.timeIntervalSinceReferenceDate + 2,
            windowCap: 1
        ))
    }

    func testR11BridgeDefaultShadowCannotReplaceR10Move() {
        let state = position(black: [0,2,4,6,8,10], white: [109,110,111,67,82,97])
        let limits = VeilEclipseStrategicPlannerR10.Limits(
            depth: 2, rootWidth: 4, replyWidth: 4, maxNodes: 1,
            maxMilliseconds: 1, tableCap: 0
        )
        let incumbent = VeilEclipseStrategicPlannerR10.choose(
            position: state, vettedRoots: [52,108,112,140],
            rootPreferences: [52:100_000], limits: limits
        )
        let bridge = VeilEclipseR11DecisionBridge.choose(
            position: state, vettedRoots: [52,108,112,140],
            rootPreferences: [52:100_000], limits: limits
        )
        XCTAssertEqual(incumbent?.index, bridge.decision?.index)
        XCTAssertEqual(bridge.rejectedUnsafeRoots, 0)
    }
}
