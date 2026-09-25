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
}
