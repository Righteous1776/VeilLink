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
        // No forced counterattack exists here, so 112 really IS the only
        // safe root. The old [0,2,4,6,8] fixture also permits winning attacks
        // at 3/5; a wall-clock-limited R4 search may legitimately prefer one.
        let defender = [0, 2, 4, 30, 32]
        for i in 0..<defender.count {
            XCTAssertTrue(state.apply(index: attacker[i], actor: .host))
            XCTAssertTrue(state.apply(index: defender[i], actor: .guest))
        }
        XCTAssertTrue(state.apply(index: attacker[5], actor: .host))
        XCTAssertEqual(GomokuCounterForkR4.safeCandidates(
            in: state, player: .guest,
            candidates: (0..<(GomokuState.size * GomokuState.size)).filter { state.value(at: $0) == 0 }
        ).moves, [112], "Fixture must have exactly one rule-safe escape")
        // Freeze both newer ordering and newer forced-win proof for R4.
        let decision = GomokuBot.chooseMove(
            in: state, for: .guest,
            budget: GomokuBotBudget.standard(profileLabel: "LEGACY-COMPACT"),
            diagnosticUseR6Defense: false,
            diagnosticR8ForcedWin: false
        )
        XCTAssertEqual(decision?.index, 112,
                       "Search must not discard the only fork-neutralizing root move")
        if let decision {
            XCTAssertTrue(state.apply(index: decision.index, actor: .guest))
            XCTAssertEqual(GomokuCounterForkR4.forkCellCount(in: state, opponent: .host), 0)
        }
    }



    func testR8FindsProvenForcingAttackRegardlessOfR4SearchTiming() {
        var state = GomokuState()
        let host = [109, 110, 111, 67, 82, 97]
        let guest = [0, 2, 4, 6, 8]
        for i in 0..<guest.count {
            XCTAssertTrue(state.apply(index: host[i], actor: .host))
            XCTAssertTrue(state.apply(index: guest[i], actor: .guest))
        }
        XCTAssertTrue(state.apply(index: host[5], actor: .host))
        XCTAssertNil(state.winner)
        XCTAssertEqual(state.currentPlayer, .guest)
        let budget = GomokuBotBudget.standard(profileLabel: "LEGACY-COMPACT")
        // The legacy heuristic search is wall-clock-limited: it may block
        // at 112 OR discover a valid winning counterattack. Do not mistake
        // a stronger legal reply for a regression under a different CI load.
        let defensive = GomokuBot.chooseMove(
            in: state, for: .guest, budget: budget,
            diagnosticR8ForcedWin: false
        )
        XCTAssertNotNil(defensive)
        if let defensive {
            XCTAssertTrue(
                GomokuCounterForkR4.forkCellCount(in: state, opponent: .host,
                    virtualBlock: defensive.index) == 0
                || GomokuCounterForkR4.createsForcedDoubleWin(in: state,
                    player: .guest, virtualPlacement: defensive.index),
                "Legacy search must block ALL opponent forks or prove a winning counterattack"
            )
            var legacyContinuation = state
            XCTAssertTrue(legacyContinuation.apply(index: defensive.index, actor: .guest))
        }

        // R8 instead identifies a rule-proven double immediate victory.
        let offensive = GomokuBot.chooseMove(in: state, for: .guest, budget: budget)
        XCTAssertEqual(offensive?.index, 3)
        XCTAssertTrue(GomokuCounterForkR4.createsForcedDoubleWin(
            in: state, player: .guest, virtualPlacement: 3
        ))
        XCTAssertTrue(state.apply(index: 3, actor: .guest))

        // Each possible single endpoint block leaves the other winning
        // endpoint. Check both continuations with the ACTUAL rule engine.
        for (hostBlock, guestWin) in [(1, 5), (5, 1)] {
            var continuation = state
            XCTAssertTrue(continuation.apply(index: hostBlock, actor: .host))
            XCTAssertTrue(continuation.apply(index: guestWin, actor: .guest))
            XCTAssertEqual(continuation.winner, .guest)
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
                        diagnosticCounterForkR4: r4Player,
                        diagnosticUseR6Defense: false,
                        diagnosticR8ForcedWin: false // R5 compares frozen R4 vs R3
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



    /// R6 held-out coefficients are tested against exact Swift bounds; this
    /// proves the model is executable, not that it wins against humans.
    func testR6TrainedPolicyIsDeterministicBoundedAndDistinctFromR4() {
        var board = GomokuState()
        XCTAssertTrue(board.apply(index: 112, actor: .host))
        XCTAssertTrue(board.apply(index: 111, actor: .guest))
        let indices = [97, 98, 113, 127, 140]
        let values = indices.map {
            GomokuCounterForkR4.trainedR6DefensiveBonus(
                in: board, player: .host, index: $0
            )
        }
        XCTAssertEqual(values, indices.map {
            GomokuCounterForkR4.trainedR6DefensiveBonus(
                in: board, player: .host, index: $0
            )
        })
        XCTAssertTrue(values.allSatisfy { (-48_000...48_000).contains($0) })
        XCTAssertEqual(GomokuCounterForkR4.trainedR6DefensiveBonus(
            in: board, player: .host, index: 112
        ), 0)
        XCTAssertTrue(indices.contains {
            GomokuCounterForkR4.trainedR6DefensiveBonus(
                in: board, player: .host, index: $0
            ) != GomokuCounterForkR4.trainedDefensiveBonus(
                in: board, player: .host, index: $0
            )
        })
    }

    /// 4 matched central openings × seat reversal: genuine native GomokuBot
    /// decision loop in BOTH branches. Both use the exact same R4 safety gate;
    /// only the seven R6-vs-R4 trained coefficients differ.
    /// Never count a truncated match as a win or draw.
    func testR6VersusR4NativePairedPolicyDiagnostic() {
        let openings = [112, 111, 97, 98]
        let budget = GomokuBotBudget(
            candidateRadius: 2, rootCandidateLimit: 8,
            replyCandidateLimit: 4, continuationCandidateLimit: 0,
            timeLimitMilliseconds: 30
        )
        var r6Wins = 0, r4Wins = 0, draws = 0, unfinished = 0
        var legalPlies = 0, changedDecisions = 0, measuredSharedPositions = 0
        var decisionSeconds = 0.0

        for opening in openings {
            for r6Host in [true, false] {
                var board = GomokuState()
                XCTAssertTrue(board.apply(index: opening, actor: .host))
                while board.winner == nil && !board.isDraw && board.moveCount < 180 {
                    let player = board.currentPlayer
                    let useR6 = (player == .host) == r6Host
                    let started = Date.timeIntervalSinceReferenceDate
                    let move = GomokuBot.chooseMove(
                        in: board, for: player, budget: budget,
                        diagnosticUseR6Defense: useR6,
                        diagnosticR8ForcedWin: false
                    )
                    decisionSeconds += Date.timeIntervalSinceReferenceDate - started
                    guard let move else {
                        XCTFail("Native bot returned nil in playable game, opening \(opening)")
                        return
                    }
                    // A limited same-position counterfactual sample measures
                    // whether two fitted models really change native choices.
                    if board.moveCount % 13 == 0 {
                        let comparison = GomokuBot.chooseMove(
                            in: board, for: player, budget: budget,
                            diagnosticUseR6Defense: !useR6,
                            diagnosticR8ForcedWin: false
                        )
                        measuredSharedPositions += 1
                        if comparison?.index != move.index {
                            changedDecisions += 1
                        }
                    }
                    guard board.apply(index: move.index, actor: player) else {
                        XCTFail("Native illegal action \(move.index), opening \(opening)")
                        return
                    }
                    legalPlies += 1
                }
                if let winner = board.winner {
                    if (winner == .host) == r6Host { r6Wins += 1 }
                    else { r4Wins += 1 }
                } else if board.isDraw {
                    draws += 1
                } else {
                    unfinished += 1
                }
            }
        }
        XCTAssertEqual(r6Wins + r4Wins + draws + unfinished, 8)
        XCTAssertGreaterThan(legalPlies, 0)
        print("R6_PAIRED_NATIVE_AB games=8 r6=\(r6Wins) r4=\(r4Wins) draws=\(draws) unfinished=\(unfinished) legalPlies=\(legalPlies) comparablePositions=\(measuredSharedPositions) changedDecisions=\(changedDecisions) meanMoveMs=\(decisionSeconds * 1000 / Double(legalPlies))")
    }



    /// Public CI fixtures deliberately use synthetic crossing formations,
    /// NOT the owner's private game histories. Private real-game replay
    /// parity is independently verified off GitHub: 394 forced positions,
    /// plus 826 genuine negative controls, 0 Swift/Python mismatches.
    func testR8SyntheticCrossingFormationHasForcedWinEvenAtTightBudget() {
        var board = GomokuState()
        let host = [109, 110, 111, 67, 82, 97]
        let guest = [0, 2, 4, 6, 8, 10]
        for i in 0..<host.count {
            XCTAssertTrue(board.apply(index: host[i], actor: .host))
            XCTAssertTrue(board.apply(index: guest[i], actor: .guest))
        }
        XCTAssertNil(board.winner)
        XCTAssertEqual(board.currentPlayer, .host)
        // Three geometrically distinct forced fork candidates exist: 52,
        // 108, 112. We select minimum legal root deterministically.
        XCTAssertEqual(GomokuCounterForkR4.immediateTwoTurnWinCandidate(
            in: board, player: .host, candidates: [52, 112, 140]
        ), 52)
        let played = GomokuBot.chooseMove(
            in: board, for: .host,
            budget: GomokuBotBudget(
                candidateRadius: 2, rootCandidateLimit: 8,
                replyCandidateLimit: 4, continuationCandidateLimit: 0,
                timeLimitMilliseconds: 0
            )
        )
        XCTAssertEqual(played?.index, 52)
        XCTAssertTrue(GomokuCounterForkR4.createsForcedDoubleWin(
            in: board, player: .host, virtualPlacement: 52
        ))
    }

    func testR8SyntheticCounterattackIsARealDoubleWin() {
        var board = GomokuState()
        let host = [109, 110, 111, 67, 82, 97, 0]
        let guest = [158, 159, 160, 116, 131, 146]
        for i in 0..<guest.count {
            XCTAssertTrue(board.apply(index: host[i], actor: .host))
            XCTAssertTrue(board.apply(index: guest[i], actor: .guest))
        }
        XCTAssertTrue(board.apply(index: host[6], actor: .host))
        XCTAssertEqual(board.currentPlayer, .guest)
        XCTAssertNil(board.winner)
        // Two-arm winning forks at 101, 157 and 161 are verified by
        // independent window-rule replay. The minimum is 101.
        XCTAssertEqual(GomokuCounterForkR4.immediateTwoTurnWinCandidate(
            in: board, player: .guest, candidates: [101, 112, 161]
        ), 101)
        let chosen = GomokuBot.chooseMove(
            in: board, for: .guest, budget: .deterministicTest
        )
        XCTAssertEqual(chosen?.index, 101)
        XCTAssertTrue(GomokuCounterForkR4.createsForcedDoubleWin(
            in: board, player: .guest, virtualPlacement: 101
        ))
    }

    /// Complete actual native engine / real GomokuState screening. R8 and R6
    /// play identical openings and opposite seats with all R6 weights, exact
    /// defense and search budgets identical. Only forced-win-in-two detector
    /// differs. A 12-game smoke is NOT Elo and a loss must not fail CI.
    func testR8VersusR6NativeFullGameSmoke() {
        let openings = [112, 111, 113, 97]
        let budget = GomokuBotBudget(
            candidateRadius: 2, rootCandidateLimit: 8,
            replyCandidateLimit: 4, continuationCandidateLimit: 0,
            timeLimitMilliseconds: 30
        )
        var r8 = 0, r6 = 0, draws = 0, unfinished = 0, legalPlies = 0
        var elapsed = 0.0
        for opening in openings {
            for r8Host in [true, false] {
                var board = GomokuState()
                XCTAssertTrue(board.apply(index: opening, actor: .host))
                while board.winner == nil && !board.isDraw && board.moveCount < 180 {
                    let actor = board.currentPlayer
                    let advanced = (actor == .host) == r8Host
                    let started = Date.timeIntervalSinceReferenceDate
                    guard let next = GomokuBot.chooseMove(
                        in: board, for: actor, budget: budget,
                        diagnosticR8ForcedWin: advanced
                    ) else {
                        XCTFail("Native move missing on active game")
                        return
                    }
                    elapsed += Date.timeIntervalSinceReferenceDate - started
                    guard board.apply(index: next.index, actor: actor) else {
                        XCTFail("Native move illegal: \(next.index)")
                        return
                    }
                    legalPlies += 1
                }
                if let winner = board.winner {
                    if (winner == .host) == r8Host { r8 += 1 }
                    else { r6 += 1 }
                } else if board.isDraw {
                    draws += 1
                } else {
                    unfinished += 1
                }
            }
        }
        XCTAssertEqual(r8 + r6 + draws + unfinished, 8)
        XCTAssertGreaterThan(legalPlies, 0)
        print("R8_PAIRED_NATIVE_AB matches=8 R8=\(r8) R6=\(r6) draws=\(draws) unfinished=\(unfinished) legalPlies=\(legalPlies) meanMs=\(elapsed*1000/Double(legalPlies))")
    }



    func testUserCanKeepDeepGomokuSearchOnLegacyHardwareByChoice() {
        // Hardware labels are NOT passed to the active chess budget chooser.
        // Full depth is the default until the user explicitly opts into economy.
        XCTAssertEqual(BoardSearchMode.restore(nil), .full)
        XCTAssertEqual(BoardSearchMode.restore("invalid-old-value"), .full)
        XCTAssertEqual(BoardSearchMode.restore("economy"), .economy)
        let full = GomokuBotBudget.forDifficulty(
            .master, profileLabel: BoardSearchMode.full.budgetProfileLabel
        )
        let saving = GomokuBotBudget.forDifficulty(
            .master, profileLabel: BoardSearchMode.economy.budgetProfileLabel
        )
        XCTAssertEqual(full.timeLimitMilliseconds, 950)
        XCTAssertEqual(saving.timeLimitMilliseconds, 420)
        XCTAssertGreaterThan(full.rootCandidateLimit, saving.rootCandidateLimit)
        XCTAssertGreaterThan(full.continuationCandidateLimit, saving.continuationCandidateLimit)
    }


}
