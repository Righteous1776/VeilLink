import XCTest
@testable import VeilLink

final class BoardBotDifficultyTests: XCTestCase {
    func testGomokuBudgetsIncreaseWithDifficulty() {
        let profile = "IPHONE7 LEGACY"
        let trainee = BoardBotDifficulty.trainee.gomokuBudget(profileLabel: profile)
        let standard = BoardBotDifficulty.strategist.gomokuBudget(profileLabel: profile)
        let master = BoardBotDifficulty.master.gomokuBudget(profileLabel: profile)

        XCTAssertLessThan(trainee.rootCandidateLimit, standard.rootCandidateLimit)
        XCTAssertLessThan(trainee.replyCandidateLimit, standard.replyCandidateLimit)
        XCTAssertLessThan(trainee.timeLimitMilliseconds, standard.timeLimitMilliseconds)

        XCTAssertGreaterThan(master.rootCandidateLimit, standard.rootCandidateLimit)
        XCTAssertGreaterThan(master.replyCandidateLimit, standard.replyCandidateLimit)
        XCTAssertGreaterThan(master.timeLimitMilliseconds, standard.timeLimitMilliseconds)
    }

    func testXiangqiBudgetsIncreaseWithDifficulty() {
        let profile = "IPHONE7 LEGACY"
        let trainee = BoardBotDifficulty.trainee.xiangqiBudget(profileLabel: profile)
        let standard = BoardBotDifficulty.strategist.xiangqiBudget(profileLabel: profile)
        let master = BoardBotDifficulty.master.xiangqiBudget(profileLabel: profile)

        XCTAssertLessThan(trainee.maxDepth, standard.maxDepth)
        XCTAssertLessThan(trainee.timeLimitMilliseconds, standard.timeLimitMilliseconds)
        XCTAssertGreaterThan(master.maxDepth, standard.maxDepth)
        XCTAssertGreaterThan(master.timeLimitMilliseconds, standard.timeLimitMilliseconds)
    }

    func testAllLudoDifficultyTiersReturnRuleLegalAction() {
        let sessionID = "00000000-0000-0000-0000-000000000001"
        var state = LudoState()
        let hostLegal = state.legalPieces(sessionID: sessionID)
        XCTAssertTrue(
            state.apply(
                pieceIndex: hostLegal.first ?? -1,
                actor: .host,
                sessionID: sessionID
            )
        )

        for difficulty in BoardBotDifficulty.allCases {
            let move = LudoBot.chooseMove(
                in: state,
                for: .guest,
                sessionID: sessionID,
                difficulty: difficulty
            )
            XCTAssertNotNil(move, "missing move for \(difficulty)")
            guard let move else { continue }

            var gate = state
            XCTAssertTrue(
                gate.apply(
                    pieceIndex: move.pieceIndex,
                    actor: .guest,
                    sessionID: sessionID
                ),
                "illegal move for \(difficulty): \(move.pieceIndex)"
            )
        }
    }

    func testTelemetryDetailMatchesGameFamily() {
        let profile = "IPHONE7 LEGACY"
        XCTAssertTrue(
            BoardBotDifficulty.master
                .telemetryDetail(profileLabel: profile, game: .gomoku)
                .contains("候选")
        )
        XCTAssertTrue(
            BoardBotDifficulty.master
                .telemetryDetail(profileLabel: profile, game: .xiangqi)
                .contains("深度")
        )
        XCTAssertTrue(
            BoardBotDifficulty.master
                .telemetryDetail(profileLabel: profile, game: .ludo)
                .contains("最佳回复")
        )
    }
}
