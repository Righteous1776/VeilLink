import XCTest
@testable import VeilLink

final class GomokuBotTests: XCTestCase {
    func testEmptyBoardChoosesCenter() {
        let move = GomokuBot.chooseMove(in: GomokuState(), for: .host, budget: .deterministicTest)
        XCTAssertEqual(move?.index, 112)
    }

    func testBotMoveAlwaysPassesRuleEngine() {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let result = GomokuBot.chooseMove(in: state, for: .guest, budget: .deterministicTest)
        XCTAssertNotNil(result)
        guard let result else { return }
        XCTAssertEqual(state.value(at: result.index), 0)
        XCTAssertTrue(state.apply(index: result.index, actor: .guest))
    }

    func testTinyTimeBudgetStillReturnsLegalMoveOnEmptyBoard() {
        let tiny = GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 20,
                                   replyCandidateLimit: 10, continuationCandidateLimit: 0,
                                   timeLimitMilliseconds: 1)
        let state = GomokuState()
        let result = GomokuBot.chooseMove(in: state, for: .host, budget: tiny)
        XCTAssertNotNil(result, "A time-budget exhaustion must not suppress a legal suggestion")
        guard let result else { return }
        XCTAssertEqual(state.value(at: result.index), 0)
        var replay = state
        XCTAssertTrue(replay.apply(index: result.index, actor: .host))
    }

    func testZeroRadiusWithOccupiedCenterReturnsAnotherLegalMove() {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let tiny = GomokuBotBudget(candidateRadius: 0, rootCandidateLimit: 1,
                                   replyCandidateLimit: 1, continuationCandidateLimit: 0,
                                   timeLimitMilliseconds: 1)
        let result = GomokuBot.chooseMove(in: state, for: .guest, budget: tiny)
        XCTAssertNotNil(result)
        guard let result else { return }
        XCTAssertNotEqual(result.index, 112)
        XCTAssertEqual(state.value(at: result.index), 0)
        XCTAssertTrue(state.apply(index: result.index, actor: .guest))
    }

    func testLegacyBudgetIsBounded() {
        let budget = GomokuBotBudget.standard(profileLabel: "LEGACY-COMPACT")
        XCTAssertLessThanOrEqual(budget.timeLimitMilliseconds, 160)
        XCTAssertLessThanOrEqual(budget.rootCandidateLimit, 18)
    }

    func testDifficultyBudgetsIncreaseSearchCapacityWhileRetainingLearningPath() {
        let relaxed = GomokuBotBudget.forDifficulty(.relaxed, profileLabel: "A16-HIGH")
        let master = GomokuBotBudget.forDifficulty(.master, profileLabel: "A16-HIGH")
        XCTAssertLessThan(relaxed.rootCandidateLimit, master.rootCandidateLimit)
        XCTAssertLessThan(relaxed.replyCandidateLimit, master.replyCandidateLimit)
        XCTAssertLessThan(relaxed.timeLimitMilliseconds, master.timeLimitMilliseconds)
        XCTAssertEqual(relaxed.continuationCandidateLimit, 0)
        XCTAssertGreaterThan(master.continuationCandidateLimit, 0)
        let trainedRelaxed = relaxed.reinforced(by: 8)
        XCTAssertGreaterThan(trainedRelaxed.rootCandidateLimit, relaxed.rootCandidateLimit)
        XCTAssertGreaterThan(trainedRelaxed.replyCandidateLimit, relaxed.replyCandidateLimit)
    }
}
