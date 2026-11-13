import Foundation

/// Compile together with the original PR193 source, mechanically renamed
/// BaselineGomokuUnifiedSearch, plus the proposed source and trained model.
@main
struct EclipseBaselineParity {
    struct RNG {
        var state: UInt64 = 0xABBABEEF93755192
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
    static func main() {
        var rng = RNG()
        var checked = 0
        for game in 0..<50 {
            var state = GomokuState()
            let count = 6 + game % 25
            while state.moveCount < count {
                let r = 3 + Int(rng.next() % 9), c = 3 + Int(rng.next() % 9)
                var trial = state
                if trial.apply(index: r * 15 + c, actor: trial.currentPlayer), trial.winner == nil { state = trial }
            }
            let cells = state.board.map { UInt8($0) }
            let side: UInt8 = state.currentPlayer == .host ? 1 : 2
            var old = BaselineGomokuUnifiedSearch.Limits()
            old.maxDepth = 3; old.width = 8; old.maxNodes = 1_000
            old.maxMilliseconds = 60_000; old.forcedLineDepth = 0
            var proposed = VeilGomokuUnifiedSearch.Limits()
            proposed.maxDepth = old.maxDepth; proposed.width = old.width; proposed.maxNodes = old.maxNodes
            proposed.maxMilliseconds = old.maxMilliseconds; proposed.forcedLineDepth = old.forcedLineDepth
            let baseline = BaselineGomokuUnifiedSearch.decide(
                BaselineGomokuUnifiedSearch.Position(cells: cells, toMove: side)!, limits: old)!
            let changed = VeilGomokuUnifiedSearch.decide(
                VeilGomokuUnifiedSearch.Position(cells: cells, toMove: side)!, limits: proposed, trainedPolicy: false)!
            guard baseline.index == changed.index, baseline.score == changed.score,
                  baseline.nodes == changed.nodes, baseline.completedDepth == changed.completedDepth,
                  baseline.rule == changed.rule, baseline.variation == changed.variation else {
                fatalError("Baseline changed at random board \(game): old=\(baseline) proposed=\(changed)")
            }
            checked += 1
        }
        print("ECLIPSE_BASELINE_PARITY_PASS positions=\(checked) move+score+nodes+depth+rule+variation")
    }
}
