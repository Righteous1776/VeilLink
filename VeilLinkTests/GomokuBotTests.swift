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

    func testR3LearnedForkPolicyIsNonzeroOnIntersectingThreatsAndBounded() {
        var board = GomokuState()
        // Host three-horizontal + three-vertical approach the same 7,7 point.
        // Guest moves are intentionally far apart; neither player has already won.
        let host = [109, 110, 111, 67, 82, 97]
        let guest = [0, 2, 4, 6, 8, 10]
        for j in 0..<host.count {
            XCTAssertTrue(board.apply(index: host[j], actor: .host))
            XCTAssertTrue(board.apply(index: guest[j], actor: .guest))
        }
        XCTAssertNil(board.winner)
        let trained = GomokuBot.trainedR3ForkBonus(index: 112, state: board, player: .host)
        XCTAssertGreaterThan(trained, 0)
        XCTAssertLessThanOrEqual(trained, 2_400)
        XCTAssertEqual(GomokuBot.trainedR3ForkBonus(index: 109, state: board, player: .host), 0)
        XCTAssertEqual(GomokuBot.trainedR3ForkBonus(index: 112, state: GomokuState(), player: .host), 0)
    }


    func testR4DefenderDetectsARealForkAndKeepsOnlySafeEscapes() {
        // Opponent has intersecting horizontal/vertical three-in-five
        // threats. The future fork at the intersection must be blocked.
        var board = GomokuState()
        let host = [109, 110, 111, 67, 82, 97]
        let guest = [0, 2, 4, 6, 8]
        for i in 0..<guest.count {
            XCTAssertTrue(board.apply(index: host[i], actor: .host))
            XCTAssertTrue(board.apply(index: guest[i], actor: .guest))
        }
        XCTAssertTrue(board.apply(index: host[5], actor: .host))
        XCTAssertNil(board.winner)
        XCTAssertEqual(board.currentPlayer, .guest)

        let before = GomokuCounterForkR4.forkCellCount(in: board, opponent: .host)
        XCTAssertGreaterThan(before, 0)
        XCTAssertEqual(GomokuCounterForkR4.forkCellCount(
            in: board, opponent: .host, virtualBlock: 112
        ), 0)
        let guarded = GomokuCounterForkR4.safeCandidates(
            in: board, player: .guest, candidates: [112, 140, 141]
        )
        XCTAssertTrue(guarded.underThreat)
        XCTAssertEqual(guarded.moves, [112])
        XCTAssertNotEqual(
            GomokuCounterForkR4.trainedDefensiveBonus(in: board, player: .guest, index: 112), 0
        )
    }

    func testR4DefenderLeavesNonThreatenedOpeningUnchanged() {
        var board = GomokuState()
        XCTAssertTrue(board.apply(index: 112, actor: .host))
        let oldCandidates = [111, 113, 96, 98]
        let guarded = GomokuCounterForkR4.safeCandidates(
            in: board, player: .guest, candidates: oldCandidates
        )
        XCTAssertFalse(guarded.underThreat)
        XCTAssertEqual(guarded.moves, oldCandidates)
        XCTAssertEqual(GomokuCounterForkR4.forkCellCount(in: board, opponent: .host), 0)
    }

    func testR4DefensiveModelIsDeterministicBoundedAndNoModelFileNeeded() {
        var board = GomokuState()
        XCTAssertTrue(board.apply(index: 112, actor: .host))
        XCTAssertTrue(board.apply(index: 111, actor: .guest))
        let scores = [97, 98, 113, 127].map {
            GomokuCounterForkR4.trainedDefensiveBonus(in: board, player: .host, index: $0)
        }
        XCTAssertEqual(scores, [97, 98, 113, 127].map {
            GomokuCounterForkR4.trainedDefensiveBonus(in: board, player: .host, index: $0)
        })
        XCTAssertTrue(scores.allSatisfy { (-48_000...48_000).contains($0) })
        XCTAssertEqual(GomokuCounterForkR4.trainedDefensiveBonus(
            in: board, player: .host, index: 112
        ), 0)
    }


    func testR4ActualNativeBotUsesForcedForkEscapeUnderLegacyBudget() {
        var state = GomokuState()
        let attacker = [109, 110, 111, 67, 82, 97]
        let defender = [0, 2, 4, 6, 8]
        for i in 0..<defender.count {
            XCTAssertTrue(state.apply(index: attacker[i], actor: .host))
            XCTAssertTrue(state.apply(index: defender[i], actor: .guest))
        }
        XCTAssertTrue(state.apply(index: attacker[5], actor: .host))
        let decision = GomokuBot.chooseMove(
            in: state, for: .guest,
            budget: GomokuBotBudget.standard(profileLabel: "LEGACY-COMPACT")
        )
        XCTAssertEqual(decision?.index, 112,
                       "Search must not discard the only fork-neutralizing root move")
        if let decision {
            XCTAssertTrue(state.apply(index: decision.index, actor: .guest))
            XCTAssertEqual(GomokuCounterForkR4.forkCellCount(in: state, opponent: .host), 0)
        }
    }



    func testR4DoesNotThrowAwayUnstoppableCounterattack() {
        var state = GomokuState()
        // Host threatens to fork at 112 while Guest can create a separate
        // unanswerable double five at 161. A purely defensive gate would
        // accidentally remove the winning counterattack.
        let host = [109, 110, 111, 67, 82, 97, 0]
        let guest = [158, 159, 160, 116, 131, 146]
        for i in 0..<guest.count {
            XCTAssertTrue(state.apply(index: host[i], actor: .host))
            XCTAssertTrue(state.apply(index: guest[i], actor: .guest))
        }
        XCTAssertTrue(state.apply(index: host[6], actor: .host))
        XCTAssertNil(state.winner)
        XCTAssertTrue(GomokuCounterForkR4.createsForcedDoubleWin(
            in: state, player: .guest, virtualPlacement: 161
        ))
        XCTAssertGreaterThan(GomokuCounterForkR4.forkCellCount(
            in: state, opponent: .host, virtualBlock: 161
        ), 0)
        let candidates = GomokuCounterForkR4.safeCandidates(
            in: state, player: .guest, candidates: [112, 161, 200]
        )
        XCTAssertTrue(candidates.underThreat)
        XCTAssertTrue(candidates.moves.contains(112))
        XCTAssertTrue(candidates.moves.contains(161))
        XCTAssertFalse(candidates.moves.contains(200))
    }



    /// R5 paired head-to-head evaluation of actual production GomokuBot paths:
    /// 6 identical central openings × 2 side reversals = 12 full native games.
    /// The R3 control disables ONLY the added R4 counterfork path; all other
    /// state rules, engine tactics, search budgets and R3 learned weights
    /// are identical. This is a screening test, not statistically valid Elo.
    func testR5PairedNativeR3VersusR4Tournament() {
        let openings = [112, 111, 113, 97, 127, 98]
        let budget = GomokuBotBudget(
            candidateRadius: 2,
            rootCandidateLimit: 8,
            replyCandidateLimit: 4,
            continuationCandidateLimit: 0,
            timeLimitMilliseconds: 38
        )
        var r4Wins = 0
        var r3Wins = 0
        var draws = 0
        var unfinished = 0
        var attempted = 0
        var legalPlyCount = 0
        var totalDecisionSeconds = 0.0

        for opening in openings {
            for r4IsHost in [true, false] {
                var board = GomokuState()
                XCTAssertTrue(board.apply(index: opening, actor: .host))
                attempted += 1
                var localPlies = 0
                while board.winner == nil && !board.isDraw && board.moveCount < 180 {
                    let actor = board.currentPlayer
                    let r4Player = (actor == .host) == r4IsHost
                    let began = Date.timeIntervalSinceReferenceDate
                    let chosen = GomokuBot.chooseMove(
                        in: board, for: actor, budget: budget,
                        diagnosticCounterForkR4: r4Player
                    )
                    totalDecisionSeconds += Date.timeIntervalSinceReferenceDate - began
                    guard let chosen else {
                        XCTFail("Native bot returned no move in live board, opening \(opening)")
                        return
                    }
                    guard board.apply(index: chosen.index, actor: actor) else {
                        XCTFail("Illegal native move \(chosen.index), opening \(opening)")
                        return
                    }
                    localPlies += 1
                    legalPlyCount += 1
                }
                if let winner = board.winner {
                    if (winner == .host) == r4IsHost { r4Wins += 1 }
                    else { r3Wins += 1 }
                } else if board.isDraw {
                    draws += 1
                } else {
                    // Explicitly exclude truncated games from W/D/L; never
                    // invent a winner from a move-limit timeout.
                    unfinished += 1
                }
                XCTAssertLessThanOrEqual(localPlies, 180)
            }
        }
        XCTAssertEqual(attempted, 12)
        XCTAssertEqual(r4Wins + r3Wins + draws + unfinished, attempted)
        XCTAssertGreaterThan(legalPlyCount, 0)
        print("R5_PAIRED_NATIVE_AB matches=\(attempted) R4=\(r4Wins) R3=\(r3Wins) draws=\(draws) unfinished=\(unfinished) legalPlies=\(legalPlyCount) meanDecisionMs=\(totalDecisionSeconds * 1000 / Double(legalPlyCount))")
    }


}
