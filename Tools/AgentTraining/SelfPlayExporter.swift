import Foundation

struct TrainingRow: Codable {
    let schema: Int
    let game: String
    let episode: Int
    let ply: Int
    let stateHash: String
    let state: [Float]
    let action: [Float]
    let label: Float
    let actionID: String
}

struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func int(_ upper: Int) -> Int { upper <= 1 ? 0 : Int(next() % UInt64(upper)) }
    mutating func chance(_ numerator: Int, _ denominator: Int) -> Bool { int(denominator) < numerator }
}

func dense(_ features: [AgentFeature], count: Int) -> [Float] {
    var result = features.map(\.value)
    if result.count > count { result = Array(result.prefix(count)) }
    if result.count < count { result.append(contentsOf: repeatElement(0, count: count - result.count)) }
    return result
}

func emitRows(
    game: MiniGameKind,
    episode: Int,
    ply: Int,
    observation: AgentGameObservation,
    candidates: [AgentActionCandidate],
    selected: AgentActionCandidate,
    file: FileHandle,
    rng: inout SplitMix64
) throws {
    let state = dense(observation.features, count: 256)
    var negatives = candidates.filter { $0.actionID != selected.actionID }
    var sampled: [AgentActionCandidate] = []
    let negativeLimit = min(6, negatives.count)
    for _ in 0..<negativeLimit {
        let index = rng.int(negatives.count)
        sampled.append(negatives.remove(at: index))
    }
    let rows = [(selected, Float(1))] + sampled.map { ($0, Float(0)) }
    let encoder = JSONEncoder()
    // JSONEncoder does not promise dictionary/key order across processes. Sorted keys make
    // equal seeded exports byte-for-byte comparable, which is important for provenance hashes.
    encoder.outputFormatting = [.sortedKeys]
    for (candidate, label) in rows {
        let row = TrainingRow(
            schema: 1,
            game: game.rawValue,
            episode: episode,
            ply: ply,
            stateHash: observation.stateHash,
            state: state,
            action: dense(candidate.features, count: 16),
            label: label,
            actionID: candidate.actionID
        )
        let data = try encoder.encode(row)
        file.write(data)
        file.write(Data([0x0A]))
    }
}

func gomokuScore(state: GomokuState, action: AgentActionCandidate, actor: MiniGamePlayer) -> Float {
    guard let text = action.metadata["index"], let index = Int(text) else { return -1000 }
    var simulated = state
    if simulated.apply(index: index, actor: actor), simulated.winner == actor { return 1000 }
    let row = index / GomokuState.size
    let col = index % GomokuState.size
    let center = Float(GomokuState.size - 1) / 2
    var score: Float = 20 - (abs(Float(row) - center) + abs(Float(col) - center))
    let own: Int8 = actor == .host ? 1 : 2
    let opp: Int8 = actor == .host ? 2 : 1
    for dr in -2...2 {
        for dc in -2...2 where !(dr == 0 && dc == 0) {
            let r = row + dr, c = col + dc
            guard (0..<GomokuState.size).contains(r), (0..<GomokuState.size).contains(c) else { continue }
            let v = state.value(at: r * GomokuState.size + c)
            if v == own { score += abs(dr) <= 1 && abs(dc) <= 1 ? 5 : 2 }
            if v == opp { score += abs(dr) <= 1 && abs(dc) <= 1 ? 4 : 1 }
        }
    }
    return score
}

func xiangqiMaterial(_ piece: XiangqiPiece) -> Float {
    switch piece.kind {
    case .general: return 100
    case .rook: return 9
    case .cannon: return 5
    case .horse: return 4.5
    case .elephant, .advisor: return 2.5
    case .soldier: return 1.5
    }
}

func xiangqiScore(state: XiangqiState, action: AgentActionCandidate, actor: MiniGamePlayer) -> Float {
    guard let fromText = action.metadata["from"], let toText = action.metadata["to"],
          let from = Int(fromText), let to = Int(toText) else { return -1000 }
    let captured = state.piece(at: to).map(xiangqiMaterial) ?? 0
    var simulated = state
    guard simulated.apply(from: from, to: to, actor: actor) else { return -1000 }
    if simulated.winner == actor { return 1000 }
    var score = captured * 20
    if simulated.isInCheck(player: actor.opponent) { score += 18 }
    if simulated.isInCheck(player: actor) { score -= 30 }
    let row = to / XiangqiState.columns
    let col = to % XiangqiState.columns
    score += Float(4 - abs(col - 4)) * 0.4
    score += actor == .host ? Float(9 - row) * 0.08 : Float(row) * 0.08
    return score
}

func ludoScore(state: LudoState, action: AgentActionCandidate, actor: MiniGamePlayer, sessionID: String) -> Float {
    guard let pieceText = action.metadata["piece"], let piece = Int(pieceText) else { return -1000 }
    if piece == -1 { return -1 }
    let before = state.pieces(for: actor)[piece]
    var simulated = state
    guard simulated.apply(pieceIndex: piece, actor: actor, sessionID: sessionID) else { return -1000 }
    if simulated.winner == actor { return 1000 }
    let after = simulated.pieces(for: actor)[piece]
    var score = Float(max(0, after - max(before, 0)))
    if before == -1 && after == 0 { score += 20 }
    if after == LudoState.finishProgress { score += 45 }
    score += Float(simulated.lastCapturedCount) * 35
    if simulated.lastMoveGrantedExtraTurn { score += 8 }
    return score
}

func choose(_ candidates: [AgentActionCandidate], scores: [Float], rng: inout SplitMix64) -> AgentActionCandidate {
    if candidates.count > 1, rng.chance(1, 8) { return candidates[rng.int(candidates.count)] }
    let best = scores.enumerated().max { a, b in
        if a.element == b.element { return a.offset > b.offset }
        return a.element < b.element
    }?.offset ?? 0
    return candidates[best]
}

func runGomoku(episodes: Int, episodeOffset: Int, file: FileHandle, rng: inout SplitMix64) throws {
    for localEpisode in 0..<episodes {
        let episode = episodeOffset + localEpisode
        var state = GomokuState()
        var ply = 0
        while state.winner == nil && !state.isDraw && ply < 225 {
            let actor = state.currentPlayer
            let adapter = GomokuAgentAdapter(state: state, actor: actor)
            let candidates = adapter.enumerateLegalActions()
            guard !candidates.isEmpty else { break }
            let scores = candidates.map { gomokuScore(state: state, action: $0, actor: actor) }
            let selected = choose(candidates, scores: scores, rng: &rng)
            try emitRows(game: .gomoku, episode: episode, ply: ply, observation: adapter.makeObservation(), candidates: candidates, selected: selected, file: file, rng: &rng)
            guard let text = selected.metadata["index"], let index = Int(text), state.apply(index: index, actor: actor) else { break }
            ply += 1
        }
    }
}

func runXiangqi(episodes: Int, episodeOffset: Int, file: FileHandle, rng: inout SplitMix64) throws {
    for localEpisode in 0..<episodes {
        let episode = episodeOffset + localEpisode
        var state = XiangqiState()
        var ply = 0
        while state.winner == nil && !state.isDraw && ply < 120 {
            let actor = state.currentPlayer
            let adapter = XiangqiAgentAdapter(state: state, actor: actor)
            let candidates = adapter.enumerateLegalActions()
            guard !candidates.isEmpty else { break }
            let scores = candidates.map { xiangqiScore(state: state, action: $0, actor: actor) }
            let selected = choose(candidates, scores: scores, rng: &rng)
            try emitRows(game: .xiangqi, episode: episode, ply: ply, observation: adapter.makeObservation(), candidates: candidates, selected: selected, file: file, rng: &rng)
            guard let f = selected.metadata["from"], let t = selected.metadata["to"], let from = Int(f), let to = Int(t), state.apply(from: from, to: to, actor: actor) else { break }
            ply += 1
        }
    }
}

func deterministicLudoSessionID(seed: UInt64, episode: Int) -> String {
    String(format: "veillink-agent-ludo-%016llx-%06d", seed, episode)
}

func runLudo(episodes: Int, episodeOffset: Int, seed: UInt64, file: FileHandle, rng: inout SplitMix64) throws {
    for localEpisode in 0..<episodes {
        let episode = episodeOffset + localEpisode
        var state = LudoState()
        // Ludo's dice stream is derived from sessionID. A random UUID made datasets differ even
        // when --seed was identical, defeating reproducible training/provenance. Bind the session
        // identity to the requested exporter seed instead.
        let sessionID = deterministicLudoSessionID(seed: seed, episode: episode)
        var ply = 0
        while state.winner == nil && ply < 500 {
            let actor = state.currentPlayer
            let adapter = LudoAgentAdapter(state: state, actor: actor, sessionID: sessionID)
            let candidates = adapter.enumerateLegalActions()
            guard !candidates.isEmpty else { break }
            let scores = candidates.map { ludoScore(state: state, action: $0, actor: actor, sessionID: sessionID) }
            let selected = choose(candidates, scores: scores, rng: &rng)
            try emitRows(game: .ludo, episode: episode, ply: ply, observation: adapter.makeObservation(), candidates: candidates, selected: selected, file: file, rng: &rng)
            guard let p = selected.metadata["piece"], let piece = Int(p), state.apply(pieceIndex: piece, actor: actor, sessionID: sessionID) else { break }
            ply += 1
        }
    }
}

@main
struct SelfPlayMain {
    static func main() throws {
        var outputPath = "agent_selfplay.jsonl"
        var episodes = 25
        var episodeOffset = 0
        var seed: UInt64 = 0x5645494C4C494E4B
        var games = Set(["gomoku", "xiangqi", "ludo"])
        var append = false
        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let key = args.removeFirst()
            switch key {
            case "--output": if !args.isEmpty { outputPath = args.removeFirst() }
            case "--episodes": if !args.isEmpty { episodes = Int(args.removeFirst()) ?? episodes }
            case "--episode-offset": if !args.isEmpty { episodeOffset = Int(args.removeFirst()) ?? episodeOffset }
            case "--seed": if !args.isEmpty { seed = UInt64(args.removeFirst()) ?? seed }
            case "--games":
                if !args.isEmpty { games = Set(args.removeFirst().split(separator: ",").map(String.init)) }
            case "--append": append = true
            default: break
            }
        }
        let allowed = Set(["gomoku", "xiangqi", "ludo"])
        guard games.isSubset(of: allowed) else {
            throw NSError(domain: "VeilLinkTraining", code: 2, userInfo: [NSLocalizedDescriptionKey: "Only gomoku, xiangqi and ludo are training-enabled. Tactical is intentionally excluded."])
        }
        if !append { _ = FileManager.default.createFile(atPath: outputPath, contents: nil) }
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))
        defer { try? handle.close() }
        if append { try handle.seekToEnd() }
        var rng = SplitMix64(state: seed)
        if games.contains("gomoku") { try runGomoku(episodes: episodes, episodeOffset: episodeOffset, file: handle, rng: &rng) }
        if games.contains("xiangqi") { try runXiangqi(episodes: episodes, episodeOffset: episodeOffset, file: handle, rng: &rng) }
        if games.contains("ludo") { try runLudo(episodes: episodes, episodeOffset: episodeOffset, seed: seed, file: handle, rng: &rng) }
        print("wrote training shard to \(outputPath); episodes/game=\(episodes); episodeOffset=\(episodeOffset); games=\(games.sorted()); tactical=EXCLUDED; append=\(append)")
    }
}
