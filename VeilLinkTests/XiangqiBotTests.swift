import XCTest
@testable import VeilLink

final class XiangqiBotTests: XCTestCase {
    func testInitialPositionHasFortyFourLegalMoves() {
        let state = XiangqiState()
        XCTAssertEqual(XiangqiBot.legalMoveCount(in: state, actor: .host), 44)
    }

    func testBotAlwaysReturnsRuleEngineLegalMove() {
        var state = XiangqiState()

        // Verified legal red cannon move:
        // 64 = row 7, col 1 -> 55 = row 6, col 1.
        XCTAssertTrue(state.apply(from: 64, to: 55, actor: .host))

        let result = XiangqiBot.chooseMove(
            in: state,
            for: .guest,
            budget: .deterministicTest
        )
        XCTAssertNotNil(result)

        guard let result else { return }
        var verified = state
        XCTAssertTrue(
            verified.apply(
                from: result.from,
                to: result.to,
                actor: .guest
            )
        )
    }

    func testSearchIsDeterministicWhenDepthCompletes() {
        var state = XiangqiState()
        XCTAssertTrue(state.apply(from: 64, to: 55, actor: .host))

        let a = XiangqiBot.chooseMove(in: state, for: .guest, budget: .deterministicTest)
        let b = XiangqiBot.chooseMove(in: state, for: .guest, budget: .deterministicTest)

        XCTAssertEqual(a?.from, b?.from)
        XCTAssertEqual(a?.to, b?.to)
        XCTAssertEqual(a?.completedDepth, b?.completedDepth)
    }

    func testLegacyBudgetIsShortAndBounded() {
        let budget = XiangqiBotBudget.standard(profileLabel: "LEGACY-COMPACT")
        XCTAssertEqual(budget.maxDepth, 4)
        XCTAssertLessThanOrEqual(budget.timeLimitMilliseconds, 200)
    }

    func testDifficultyBudgetsIncreaseSearchDepth() {
        let relaxed = XiangqiBotBudget.forDifficulty(.relaxed, profileLabel: "A16-HIGH")
        let master = XiangqiBotBudget.forDifficulty(.master, profileLabel: "A16-HIGH")
        XCTAssertLessThan(relaxed.maxDepth, master.maxDepth)
        XCTAssertLessThan(relaxed.quiescenceDepth, master.quiescenceDepth)
        XCTAssertLessThan(relaxed.timeLimitMilliseconds, master.timeLimitMilliseconds)
        let trainedRelaxed = relaxed.reinforced(by: 8)
        XCTAssertGreaterThanOrEqual(trainedRelaxed.maxDepth, relaxed.maxDepth)
        XCTAssertGreaterThan(trainedRelaxed.timeLimitMilliseconds, relaxed.timeLimitMilliseconds)
    }

    func testR3XiangqiOrderingPolicyAffectsLegalOpeningMovesWithinBounds() {
        let board = XiangqiState()
        XCTAssertTrue(board.legalDestinations(from: 64, actor: .host).contains(55))
        XCTAssertTrue(board.legalDestinations(from: 82, actor: .host).contains(65))
        let cannon = XiangqiBot.trainedR3OrderingBonus(
            in: board, from: 64, to: 55, givesCheck: false
        )
        let horse = XiangqiBot.trainedR3OrderingBonus(
            in: board, from: 82, to: 65, givesCheck: false
        )
        XCTAssertNotEqual(cannon, horse)
        XCTAssertTrue((-72...72).contains(cannon))
        XCTAssertTrue((-72...72).contains(horse))
        XCTAssertEqual(XiangqiBot.trainedR3OrderingBonus(
            in: board, from: 90, to: 0, givesCheck: false
        ), 0)
    }


    func testR4AllocationFreeXiangqiPriorMatchesFrozenSourceFixtures() {
        // Scores from the R3 21-feature trained model evaluated independently.
        // These are ordering bonuses, not best-move evaluations.
        let board = XiangqiState()
        XCTAssertEqual(XiangqiBot.trainedR3OrderingBonus(
            in: board, from: 64, to: 55, givesCheck: false
        ), -11)
        XCTAssertEqual(XiangqiBot.trainedR3OrderingBonus(
            in: board, from: 82, to: 65, givesCheck: false
        ), 4)
        XCTAssertEqual(XiangqiBot.trainedR3OrderingBonus(
            in: board, from: 81, to: 72, givesCheck: false
        ), -13)
        XCTAssertEqual(XiangqiBot.trainedR3OrderingBonus(
            in: board, from: 54, to: 45, givesCheck: false
        ), 2)
    }

}
