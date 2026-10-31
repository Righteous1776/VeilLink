import Foundation

/// An opt-in preference layered below winning/forced-block tactics.
/// The 14,244 synthetic diagrams are recognition data, not best-move labels.
enum GomokuFormationMode: String, CaseIterable, Identifiable, Sendable {
    case off, automatic, bagua, attack, defense, discovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭阵法偏好"
        case .automatic: return "Bot 自主选择"
        case .bagua: return "八卦阵 · 马步联结"
        case .attack: return "进攻阵 · 活三冲四"
        case .defense: return "防守阵 · 封堵"
        case .discovery: return "探索新阵法"
        }
    }

    var detail: String {
        switch self {
        case .off: return "原有棋力策略，不改变落子"
        case .automatic: return "结合攻防与已识别的马步结构，自动调整微弱偏好"
        case .bagua: return "偏好同色连续落子成马步，但不牺牲必胜/必防"
        case .attack: return "偏好形成连接与后续威胁"
        case .defense: return "偏好封堵对方的潜在连接"
        case .discovery: return "根据已经完成的对局挖掘候选，不宣称未经验证的必胜阵"
        }
    }
}

struct GomokuFormationPreference: Sendable {
    static let disabled = GomokuFormationPreference(mode: .off, aiHistory: [], discovered: [])

    let mode: GomokuFormationMode
    let aiHistory: [Int]
    let discovered: [String]

    var enabled: Bool { mode != .off }

    /// Tactical urgency is evaluated once per search, never per candidate.
    static func opponentHasImmediateWin(in state: GomokuState, player: MiniGamePlayer) -> Bool {
        let opponent: Int8 = player == .host ? 2 : 1
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for row in 0..<GomokuState.size {
            for column in 0..<GomokuState.size {
                for (dr, dc) in directions {
                    let endRow = row + dr * 4
                    let endCol = column + dc * 4
                    guard (0..<GomokuState.size).contains(endRow),
                          (0..<GomokuState.size).contains(endCol) else { continue }
                    var opponents = 0
                    var empties = 0
                    for step in 0..<5 {
                        let index = (row + dr * step) * GomokuState.size + column + dc * step
                        switch state.value(at: index) {
                        case opponent: opponents += 1
                        case 0: empties += 1
                        default: break
                        }
                    }
                    if opponents == 4 && empties == 1 { return true }
                }
            }
        }
        return false
    }

    func bonus(index: Int, state: GomokuState, player: MiniGamePlayer, urgentDefense: Bool) -> Int {
        guard enabled, !urgentDefense, (0..<(GomokuState.size * GomokuState.size)).contains(index),
              state.value(at: index) == 0 else { return 0 }
        let own: Int8 = player == .host ? 1 : 2
        let other: Int8 = player == .host ? 2 : 1
        let attack = adjacent(index: index, stone: own, state: state)
        let defend = adjacent(index: index, stone: other, state: state)
        let knight = aiHistory.last.map { Self.isKnight(from: $0, to: index) } ?? false
        // Keep the prior search's tactical ranking dominant: never approach
        // the scale of an immediate four/five threat.
        switch mode {
        case .off: return 0
        case .automatic:
            return min(320, (defend > attack ? defend * 38 : attack * 32) + (knight ? 65 : 0))
        case .bagua:
            return min(320, (knight ? 240 : 0) + attack * 16)
        case .attack:
            return min(320, attack * 55)
        case .defense:
            return min(320, defend * 55)
        case .discovery:
            let tentative = Self.signature(Array(aiHistory.suffix(3)) + [index])
            return min(320, (tentative.map { discovered.contains($0) } ?? false ? 220 : 0)
                + attack * 15 + (knight ? 40 : 0))
        }
    }

    private func adjacent(index: Int, stone: Int8, state: GomokuState) -> Int {
        let row = index / GomokuState.size
        let column = index % GomokuState.size
        var count = 0
        for dr in -2...2 {
            for dc in -2...2 where dr != 0 || dc != 0 {
                let rr = row + dr
                let cc = column + dc
                if (0..<GomokuState.size).contains(rr), (0..<GomokuState.size).contains(cc),
                   state.value(at: rr * GomokuState.size + cc) == stone {
                    count += abs(dr) <= 1 && abs(dc) <= 1 ? 2 : 1
                }
            }
        }
        return count
    }

    static func isKnight(from a: Int, to b: Int) -> Bool {
        guard (0..<(GomokuState.size * GomokuState.size)).contains(a),
              (0..<(GomokuState.size * GomokuState.size)).contains(b) else { return false }
        let dr = abs(a / GomokuState.size - b / GomokuState.size)
        let dc = abs(a % GomokuState.size - b % GomokuState.size)
        return (dr == 1 && dc == 2) || (dr == 2 && dc == 1)
    }

    /// Orientation-independent movement signature from a four-move AI sequence.
    /// These are candidates for analysis, NOT established tactical strategies.
    static func signature(_ indices: [Int]) -> String? {
        guard indices.count >= 4 else { return nil }
        let tail = Array(indices.suffix(4))
        var tokens: [String] = []
        for (a, b) in zip(tail, tail.dropFirst()) {
            guard (0..<(GomokuState.size * GomokuState.size)).contains(a),
                  (0..<(GomokuState.size * GomokuState.size)).contains(b) else { return nil }
            let dr = abs(a / GomokuState.size - b / GomokuState.size)
            let dc = abs(a % GomokuState.size - b % GomokuState.size)
            if isKnight(from: a, to: b) { tokens.append("N") }
            else if dr == dc { tokens.append("D") }
            else if dr == 0 || dc == 0 { tokens.append("L") }
            else { tokens.append("X") }
        }
        return tokens.joined()
    }
}

struct GomokuFormationCandidateRecord: Codable, Sendable {
    var games: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0

    var eligibleForStudy: Bool {
        games >= 5 && wins >= 3 && wins > losses * 2
    }
}

/// Dedicated, bounded evidence registry. Never changes the learned-game store,
/// database schema or shared Xiangqi archive.
final class GomokuFormationDiscoveryStore {
    private let defaults: UserDefaults
    private let key = "VeilLink.Gomoku.FormationNovelty.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private var records: [String: GomokuFormationCandidateRecord] {
        get {
            guard let data = defaults.data(forKey: key),
                  let value = try? JSONDecoder().decode([String: GomokuFormationCandidateRecord].self, from: data)
            else { return [:] }
            return value
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }

    var candidateCount: Int { records.count }
    var eligibleSignatures: [String] {
        records.filter { $0.value.eligibleForStudy }.keys.sorted()
    }

    func record(aiMoves: [Int], outcome: AdaptiveBoardGameResult) {
        guard let signature = GomokuFormationPreference.signature(aiMoves),
              signature != "NNN" else { return }
        var all = records
        var record = all[signature] ?? GomokuFormationCandidateRecord()
        switch outcome {
        case .aiWon: record.wins += 1
        case .humanWon: record.losses += 1
        case .draw: record.draws += 1
        case .unfinished: return
        }
        record.games += 1
        all[signature] = record
        // Bound metadata on low-memory devices, independent from full game history.
        if all.count > 32 {
            let keep = all.sorted {
                let a = $0.value.wins * 2 - $0.value.losses
                let b = $1.value.wins * 2 - $1.value.losses
                return a == b ? $0.key < $1.key : a > b
            }.prefix(32)
            all = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        records = all
    }

    func clear() { defaults.removeObject(forKey: key) }
}
