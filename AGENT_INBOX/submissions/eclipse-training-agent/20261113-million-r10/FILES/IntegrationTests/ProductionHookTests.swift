import Foundation

@main
struct ProductionHookTests {
    final class TraceCapture: @unchecked Sendable {
        var events: [VeilGomokuUnifiedSearch.Trace] = []
    }
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            FileHandle.standardError.write(Data(("FAIL " + message + "\n").utf8))
            exit(2)
        }
    }
    static func replay(_ moves: [Int]) -> GomokuState {
        var state = GomokuState()
        for move in moves {
            require(state.apply(index: move, actor: state.currentPlayer), "fixture legal replay \(move)")
        }
        return state
    }
    static func legal(_ move: GomokuBotMove?, in state: GomokuState) -> Bool {
        guard let move else { return false }
        var copy = state
        return copy.apply(index: move.index, actor: copy.currentPlayer)
    }
    static func delegation(state: GomokuState,budget: GomokuBotBudget,difficulty: String?) {
        let old = GomokuBot.chooseMove(in: state, for: state.currentPlayer, budget: budget,
                                      diagnosticEclipseUnified: false,difficultyRawValue: difficulty)
        require(legal(old,in: state), "diagnostic old path remains usable")
        require(old?.engineLabel == nil, "old engine never claims ECLIPSE")
        let capture = TraceCapture()
        let direct = VeilGomokuUnifiedBridge.chooseMove(
            in: state, for: state.currentPlayer, budget: budget,
            permittedRoots: [old!.index], rootScores: [old!.index:0],
            difficultyRawValue: difficulty,onTrace: { capture.events.append($0) })
        let hooked = GomokuBot.chooseMove(in: state, for: state.currentPlayer, budget: budget,
                                         difficultyRawValue: difficulty)
        require(legal(direct,in: state) && legal(hooked,in: state), "bridge/product legal output")
        require(capture.events.first?.phase == .validating && capture.events.last?.phase == .complete,
                "actual kernel trace emitted through actual bridge")
        require(hooked?.index == direct?.index && hooked?.score == direct?.score && hooked?.nodes == direct?.nodes,
                "default actual GomokuBot delegates to real bridge/kernel")
        require(hooked?.engineLabel == "ECLIPSE · 训练策略" && direct?.engineLabel == hooked?.engineLabel,
                "actual ECLIPSE result carries actual engine label")
        require(hooked?.nodes != old?.nodes || hooked?.score != old?.score,
                "hook result differs from diagnostic old engine telemetry")
        print("PASS actual GomokuBot -> bridge -> ECLIPSE -> trained policy; side=\(state.currentPlayer) difficulty=\(difficulty ?? "nil") move=\(hooked!.index) nodes=\(hooked!.nodes) score=\(hooked!.score); oldNodes=\(old!.nodes) oldScore=\(old!.score)")
    }
    static func main() {
        let budget = GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 1,
                                     replyCandidateLimit: 4, continuationCandidateLimit: 0,
                                     timeLimitMilliseconds: 2_000)
        let empty = GomokuState()
        require(GomokuBot.chooseMove(in: empty, for: .host, budget: budget)?.index == 112,
                "actual product empty-center rule")
        print("PASS product empty-center rule")

        let winning = replay([112,97,113,98,114,99,115,140])
        for eclipse in [false,true] {
            let move = GomokuBot.chooseMove(in: winning, for: winning.currentPlayer, budget: budget,
                                           diagnosticEclipseUnified: eclipse)
            require(legal(move,in: winning) && [111,116].contains(move!.index), "product immediate win \(eclipse)")
            require(move?.score == 2_000_000, "incumbent win priority preserved")
        }
        print("PASS product mandatory win with hook enabled and disabled")

        let blocking = replay([112,111,113,95,114,96,115])
        for eclipse in [false,true] {
            let move = GomokuBot.chooseMove(in: blocking, for: blocking.currentPlayer, budget: budget,
                                           diagnosticEclipseUnified: eclipse)
            require(legal(move,in: blocking) && move?.index == 116, "product unique immediate block \(eclipse)")
            require(move?.score == 1_000_000, "incumbent mandatory block preserved")
        }
        print("PASS product mandatory block with hook enabled and disabled")

        let both = replay([112,125,113,126,114,127,115,128])
        let first = GomokuBot.chooseMove(in: both, for: both.currentPlayer, budget: budget)
        require([111,116].contains(first?.index ?? -1) && first?.score == 2_000_000,
                "product win precedes enemy block")
        print("PASS own win takes priority over opponent threat")

        let done = replay([112,97,113,98,114,99,115,140,116])
        require(GomokuBot.chooseMove(in: done, for: done.currentPlayer, budget: budget) == nil,
                "product rejects terminal board")
        require(GomokuBot.chooseMove(in: winning, for: .guest, budget: budget) == nil,
                "product rejects wrong turn")
        print("PASS product terminal and wrong-turn guards")

        // A single root lets the unmodified diagnostic old engine reveal the
        // exact incumbent ranked root independently of the new bridge.
        let regular = replay([112,96,129,98])
        for raw in [nil,"relaxed","balanced","advanced","master"] as [String?] {
            delegation(state: regular,budget: budget,difficulty: raw)
            let block = GomokuBot.chooseMove(in: blocking, for: blocking.currentPlayer,
                                            budget: budget,difficultyRawValue: raw)
            let win = GomokuBot.chooseMove(in: winning, for: winning.currentPlayer,
                                          budget: budget,difficultyRawValue: raw)
            require(block?.index == 116 && block?.score == 1_000_000,
                    "difficulty preserves mandatory block")
            require([111,116].contains(win?.index ?? -1) && win?.score == 2_000_000,
                    "difficulty preserves mandatory win")
        }
        delegation(state: replay([112,96,129]),budget: budget,difficulty: nil)
        let levels = ["relaxed","balanced","advanced","master"].map {
            EclipseDifficultyPolicy.limits(rawValue: $0,maximumMilliseconds: 2_000)
        }
        for i in 1..<levels.count {
            require(levels[i].maxDepth > levels[i-1].maxDepth &&
                    levels[i].width > levels[i-1].width &&
                    levels[i].maxNodes > levels[i-1].maxNodes,
                    "difficulty increases depth width and nodes")
        }
        for raw in ["relaxed","balanced","advanced","master"] {
            let capped = EclipseDifficultyPolicy.limits(rawValue: raw,maximumMilliseconds: 45)
            require(capped.maxMilliseconds <= 45 && capped.maxMilliseconds >= 30,
                    "difficulty respects explicit compute cap")
        }
        print("PASS four difficulty requests reach actual bridge; monotonic budgets and explicit caps; win/block unchanged")

        let cells = (0..<225).map { UInt8(regular.value(at: $0)) }
        let learned = (0..<225).filter { cells[$0] == 0 }.map {
            EclipseTrainedOrdering.score(cells: cells, index: $0, side: 1)
        }
        require(Set(learned).count > 1 && learned.contains(where: { $0 != 0 }),
                "actual exported fitted model has nonconstant candidate scores")
        let swapped = cells.map { $0 == 0 ? UInt8(0) : ($0 == 1 ? UInt8(2) : UInt8(1)) }
        for index in 0..<225 where cells[index] == 0 {
            require(EclipseTrainedOrdering.score(cells: cells,index: index,side: 1) ==
                    EclipseTrainedOrdering.score(cells: swapped,index: index,side: 2),
                    "fitted model color-relative parity")
        }
        print("PASS fitted model loaded with \(Set(learned).count) distinct candidate scores and color-relative parity")
        print("ALL PRODUCTION HOOK TESTS PASSED (Linux Swift; iOS/XCTest not run)")
    }
}
