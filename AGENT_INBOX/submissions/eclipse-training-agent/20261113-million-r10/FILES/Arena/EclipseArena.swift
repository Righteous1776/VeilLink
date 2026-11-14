import Foundation

/// Offline, source-native ECLIPSE A/B arena. Presets are explicitly recorded;
/// every later move is selected by VeilGomokuUnifiedSearch.decide itself.
/// This executable never reads or modifies an application learning database.
@main
struct EclipseArena {
    typealias K = VeilGomokuUnifiedSearch
    struct RNG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
    static func opening(pair: Int, seed: UInt64) -> [Int] {
        var rng = RNG(state: seed &+ UInt64(pair) &* 0xD1B54A32D192ED03)
        var moves = [112]
        var state = GomokuState()
        precondition(state.apply(index: 112, actor: .host))
        // Six legal preset plies, identical in both color assignments.
        while moves.count < 6 {
            let r = 4 + Int(rng.next() % 7), c = 4 + Int(rng.next() % 7)
            let idx = r * 15 + c
            var trial = state
            guard trial.apply(index: idx, actor: trial.currentPlayer), trial.winner == nil else { continue }
            state = trial
            moves.append(idx)
        }
        return moves
    }
    static func number(_ name: String, default fallback: Int) -> Int {
        guard let i = CommandLine.arguments.firstIndex(of: name),
              i + 1 < CommandLine.arguments.count,
              let x = Int(CommandLine.arguments[i+1]) else { return fallback }
        return x
    }
    static func string(_ name: String, default fallback: String) -> String {
        guard let i = CommandLine.arguments.firstIndex(of: name),
              i + 1 < CommandLine.arguments.count else { return fallback }
        return CommandLine.arguments[i+1]
    }
    static func emit(_ object: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try handle.write(contentsOf: data)
        try handle.write(contentsOf: Data([10]))
    }
    static func main() throws {
        let games = max(2, number("--games", default: 200))
        precondition(games % 2 == 0, "Arena requires complete color-swapped pairs")
        let pairOffset = max(0, number("--pair-offset", default: 0))
        let maxPlies = min(225, max(7, number("--max-plies", default: 225)))
        let seed = UInt64(max(1, number("--seed", default: 937_551_923)))
        let path = string("--output", default: "/workspace/scratch/eclipse-arena/games.jsonl")
        let outputURL = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        precondition(!FileManager.default.fileExists(atPath: path), "Refusing to overwrite arena evidence")
        _ = FileManager.default.createFile(atPath: path, contents: nil)
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }
        var limits = K.Limits()
        limits.maxDepth = max(1, number("--depth", default: 3))
        limits.width = max(1, number("--width", default: 8))
        limits.maxNodes = max(1, number("--nodes", default: 1_000))
        limits.maxMilliseconds = max(1, number("--milliseconds", default: 2_000))
        limits.forcedLineDepth = max(0, number("--forcing-depth", default: 0))
        limits.candidateRadius = 2
        let baselineTrained = CommandLine.arguments.contains("--baseline-trained")
        var baselineLimits = limits
        baselineLimits.maxDepth = max(1, number("--baseline-depth", default: limits.maxDepth))
        baselineLimits.width = max(1, number("--baseline-width", default: limits.width))
        baselineLimits.maxNodes = max(1, number("--baseline-nodes", default: limits.maxNodes))
        baselineLimits.maxMilliseconds = max(1, number("--baseline-milliseconds", default: limits.maxMilliseconds))
        baselineLimits.forcedLineDepth = max(0, number("--baseline-forcing-depth", default: limits.forcedLineDepth))
        let budget: [String: Int] = ["maxDepth": limits.maxDepth, "width": limits.width,
            "maxNodes": limits.maxNodes, "maxMilliseconds": limits.maxMilliseconds,
            "forcedLineDepth": limits.forcedLineDepth, "candidateRadius": limits.candidateRadius]
        let baselineBudget: [String: Int] = ["maxDepth": baselineLimits.maxDepth, "width": baselineLimits.width,
            "maxNodes": baselineLimits.maxNodes, "maxMilliseconds": baselineLimits.maxMilliseconds,
            "forcedLineDepth": baselineLimits.forcedLineDepth, "candidateRadius": baselineLimits.candidateRadius]
        for game in 0..<games {
            let pair = pairOffset + game / 2
            let trainedSide: UInt8 = game % 2 == 0 ? 1 : 2
            let presets = opening(pair: pair, seed: seed)
            var state = GomokuState()
            for idx in presets { precondition(state.apply(index: idx, actor: state.currentPlayer)) }
            var moves = presets
            var diagnostics: [[String: Any]] = []
            var winner: UInt8 = 0
            var invalid = ""
            let started = Date.timeIntervalSinceReferenceDate
            while moves.count < maxPlies {
                let side = UInt8(moves.count % 2 + 1)
                let challenger = side == trainedSide
                let trained = challenger || baselineTrained
                let before = Date.timeIntervalSinceReferenceDate
                let cells = state.board.map { UInt8($0) }
                let position = K.Position(cells: cells, toMove: side)!
                let decision = K.decide(position, limits: challenger ? limits : baselineLimits, trainedPolicy: trained)
                let elapsed = (Date.timeIntervalSinceReferenceDate - before) * 1_000
                guard let decision else { invalid = "nil-decision"; break }
                guard state.apply(index: decision.index, actor: state.currentPlayer) else {
                    invalid = "illegal-decision"; break
                }
                diagnostics.append(["index": decision.index, "side": Int(side), "trained": trained, "challenger": challenger,
                    "nodes": decision.nodes, "completedDepth": decision.completedDepth,
                    "rule": decision.rule, "milliseconds": elapsed])
                moves.append(decision.index)
                if let victor = state.winner { winner = victor == .host ? 1 : 2; break }
            }
            let result = !invalid.isEmpty ? "invalid" : winner != 0 ? (winner == trainedSide ? "trainedWon" : "baselineWon") : moves.count == 225 ? "draw" : "capped"
            try emit(["format": "veillink.eclipse.native-arena.v1", "pair": pair,
                "seed": seed, "trainedSide": Int(trainedSide), "presetPlies": presets.count,
                "presets": presets, "moves": moves, "winner": Int(winner), "result": result,
                "invalid": invalid, "decisions": diagnostics, "limits": budget,
                "baselineTrained": baselineTrained, "baselineLimits": baselineBudget,
                "milliseconds": (Date.timeIntervalSinceReferenceDate-started)*1_000], to: output)
            try output.synchronize()
            FileHandle.standardError.write(Data("arena game \(game+1)/\(games) pair=\(pair) trained=\(trainedSide) result=\(result) plies=\(moves.count)\n".utf8))
        }
    }
}
