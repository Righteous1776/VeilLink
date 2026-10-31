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

    func testNativeBotReturnsLegalMoveEvenWithTightExpiredSearchBudget() {
        // Even if the search deadline expires before deep evaluation starts,
        // an ongoing game still needs a legal action; only terminal states
        // and invalid turn ownership may return nil.
        let fast = GomokuBotBudget(
            candidateRadius: 2, rootCandidateLimit: 28,
            replyCandidateLimit: 16, continuationCandidateLimit: 8,
            timeLimitMilliseconds: 0
        )
        var board = GomokuState()
        let first = GomokuBot.chooseMove(in: board, for: .host, budget: fast)
        XCTAssertEqual(first?.index, 112)
        XCTAssertTrue(board.apply(index: 112, actor: .host))
        let reply = GomokuBot.chooseMove(in: board, for: .guest, budget: fast)
        XCTAssertNotNil(reply)
        if let reply {
            XCTAssertEqual(board.value(at: reply.index), 0)
            XCTAssertTrue(board.apply(index: reply.index, actor: .guest))
        }
        XCTAssertNil(GomokuBot.chooseMove(in: board, for: .guest, budget: fast),
                     "Out-of-turn requests must continue to fail closed")
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
