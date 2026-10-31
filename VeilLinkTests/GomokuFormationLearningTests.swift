import Foundation
import XCTest
@testable import VeilLink

final class GomokuFormationLearningTests: XCTestCase {
    func testKnightGeometryAndSignature() {
        XCTAssertTrue(GomokuFormationPreference.isKnight(from: 112, to: 129))
        XCTAssertTrue(GomokuFormationPreference.isKnight(from: 112, to: 83))
        XCTAssertFalse(GomokuFormationPreference.isKnight(from: 112, to: 128))
        XCTAssertFalse(GomokuFormationPreference.isKnight(from: -1, to: 129))
        XCTAssertEqual(GomokuFormationPreference.signature([112, 129, 145, 162]), "NDN")
        XCTAssertNil(GomokuFormationPreference.signature([112, 129, 145]))
    }

    func testNoModeChangesOriginalBotRootPriorities() {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let pref = GomokuFormationPreference.disabled
        XCTAssertEqual(pref.bonus(index: 113, state: state, player: .guest, urgentDefense: false), 0)
        XCTAssertEqual(pref.bonus(index: 113, state: state, player: .guest, urgentDefense: true), 0)
    }

    func testBaguaPreferenceIsBoundedAndDoesNotOverrideUrgentDefense() {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let pref = GomokuFormationPreference(mode: .bagua, aiHistory: [112], discovered: [])
        let legalKnightIndex = 129
        let optional = pref.bonus(index: legalKnightIndex, state: state, player: .guest, urgentDefense: false)
        XCTAssertGreaterThan(optional, 0)
        XCTAssertLessThanOrEqual(optional, 320)
        XCTAssertEqual(
            pref.bonus(index: legalKnightIndex, state: state, player: .guest, urgentDefense: true), 0
        )
        XCTAssertEqual(pref.bonus(index: 112, state: state, player: .guest, urgentDefense: false), 0)
    }

    func testVeilBaguaContainmentFollowsLatestOpponentDirection() {
        // White moved from (5, 5) to (6, 5), i.e. toward increasing rows.
        let opponent = [80, 95]
        XCTAssertEqual(GomokuFormationPreference.opponentEscapeVector(opponent)?.row, 1)
        XCTAssertEqual(GomokuFormationPreference.opponentEscapeVector(opponent)?.column, 0)
        XCTAssertGreaterThan(GomokuFormationPreference.frontierAlignment(index: 162, opponentHistory: opponent), 0)
        XCTAssertLessThan(GomokuFormationPreference.frontierAlignment(index: 50, opponentHistory: opponent), 0)

        let black = [112, 129, 145]
        let forward = GomokuFormationPreference.containmentBonus(
            index: 162, aiHistory: black, opponentHistory: opponent
        )
        let behind = GomokuFormationPreference.containmentBonus(
            index: 50, aiHistory: black, opponentHistory: opponent
        )
        XCTAssertGreaterThan(forward, 0)
        XCTAssertEqual(behind, 0)
        XCTAssertLessThanOrEqual(forward, 180)
    }

    func testVeilBaguaContainmentRequiresDirectionAndKnightLink() {
        XCTAssertEqual(
            GomokuFormationPreference.containmentBonus(index: 162, aiHistory: [112, 129, 145], opponentHistory: [95]),
            0
        )
        XCTAssertEqual(
            GomokuFormationPreference.containmentBonus(index: 162, aiHistory: [112], opponentHistory: [80, 95]),
            0
        )
    }

    func testVeilBaguaContainmentIsRotationConsistent() {
        // A downward escape on the original board becomes a rightward escape
        // after a clockwise rotation; the relative frontier preference holds.
        let original = GomokuFormationPreference.frontierAlignment(
            index: 162, opponentHistory: [80, 95]
        )
        let rotated = GomokuFormationPreference.frontierAlignment(
            index: 184, opponentHistory: [84, 83]
        )
        XCTAssertGreaterThan(original, 0)
        XCTAssertGreaterThan(rotated, 0)
    }

    func testDetectsOpponentFourInARow() {
        var state = GomokuState()
        let moves = [105, 0, 106, 1, 107, 2, 108]
        for (turn, index) in moves.enumerated() {
            XCTAssertTrue(state.apply(index: index, actor: turn.isMultiple(of: 2) ? .host : .guest))
        }
        XCTAssertTrue(
            GomokuFormationPreference.opponentHasImmediateWin(in: state, player: .guest)
        )
    }

    func testDiscoveryRequiresRepeatedSuccessAndNeverPromotesBaguaAsNew() {
        let suite = "studio.zeo.VeilLink.FormationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let archive = GomokuFormationDiscoveryStore(defaults: defaults)
        let novel = [112, 129, 145, 162]
        for _ in 0..<3 { archive.record(aiMoves: novel, outcome: .aiWon) }
        XCTAssertEqual(archive.candidateCount, 1)
        XCTAssertTrue(archive.eligibleSignatures.isEmpty)
        archive.record(aiMoves: novel, outcome: .draw)
        archive.record(aiMoves: novel, outcome: .aiWon)
        XCTAssertEqual(archive.eligibleSignatures, ["NDN"])
        archive.record(aiMoves: [112, 129, 146, 163], outcome: .aiWon)
        XCTAssertEqual(archive.candidateCount, 1, "All-knight is an already-known family")
        archive.clear()
        XCTAssertTrue(archive.eligibleSignatures.isEmpty)
        XCTAssertEqual(archive.candidateCount, 0)
    }

    func testNoLearningFromUnfinishedGames() {
        let suite = "studio.zeo.VeilLink.FormationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let archive = GomokuFormationDiscoveryStore(defaults: defaults)
        archive.record(aiMoves: [112, 129, 145, 162], outcome: .unfinished)
        XCTAssertEqual(archive.candidateCount, 0)
    }

    func testTacticalForcedBlockWinsOverBaguaAndNoveltyBonuses() {
        var state = GomokuState()
        for (turn, index) in [108, 0, 109, 1, 111, 2, 112].enumerated() {
            XCTAssertTrue(state.apply(index: index, actor: turn.isMultiple(of: 2) ? .host : .guest))
        }
        for mode in [GomokuFormationMode.off, .automatic, .bagua, .attack, .defense, .discovery] {
            let pref = GomokuFormationPreference(
                mode: mode, aiHistory: [112, 129, 145], discovered: ["NDN"]
            )
            let move = GomokuBot.chooseMove(
                in: state, for: .guest, budget: .deterministicTest,
                formationPreference: pref
            )
            XCTAssertEqual(move?.index, 110, "Mode \(mode.rawValue) must block direct five")
        }
    }

    func testImmediateWinOutranksAllFormationPreferences() {
        var state = GomokuState()
        for (turn, index) in [0, 123, 2, 124, 4, 125, 6, 126, 8].enumerated() {
            XCTAssertTrue(state.apply(index: index, actor: turn.isMultiple(of: 2) ? .host : .guest))
        }
        for mode in [GomokuFormationMode.off, .bagua, .automatic, .discovery] {
            let pref = GomokuFormationPreference(mode: mode, aiHistory: [112], discovered: ["NDN"])
            let move = GomokuBot.chooseMove(
                in: state, for: .guest, budget: .deterministicTest,
                formationPreference: pref
            )
            XCTAssertTrue([122, 127].contains(move?.index ?? -1),
                          "Mode \(mode.rawValue) must take immediate victory")
        }
    }

    func testNativeSearchKeepsMoveLegalWithFormationPreference() {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let pref = GomokuFormationPreference(mode: .automatic, aiHistory: [112], discovered: [])
        guard let choice = GomokuBot.chooseMove(
            in: state, for: .guest, budget: .deterministicTest,
            formationPreference: pref
        ) else {
            XCTFail("Expected a legal reply")
            return
        }
        XCTAssertTrue(state.apply(index: choice.index, actor: .guest))
    }
}
