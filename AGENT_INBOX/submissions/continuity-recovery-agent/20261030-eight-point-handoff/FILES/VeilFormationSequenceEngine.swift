import Foundation

/// Stores training episodes in separate game lanes. A forecast is a concrete
/// legal-next-action candidate, not a positional ordering-only bonus.
/// Journal persistence and live Bot wiring are later integration gates.
struct VeilFormationSequenceEngine {
    enum Game: String, Codable, Sendable { case gomoku, xiangqi }
    enum Outcome: String, Codable, Sendable { case aiWon, humanWon, draw, unfinished }
    enum Actor: String, Codable, Sendable { case human, ai }
    struct Ply: Codable, Equatable, Hashable, Sendable {
        let actor: Actor
        let action: String
    }
    struct Episode: Codable, Sendable {
        let game: Game
        let plies: [Ply]
        let outcome: Outcome
    }
    struct Forecast: Equatable, Sendable {
        let action: String
        let score: Int
        let matchedSequences: Int
        let label: String
    }

    private(set) var gomokuEpisodes: [Episode] = []
    private(set) var xiangqiEpisodes: [Episode] = []

    mutating func learn(_ episode: Episode) {
        guard !episode.plies.isEmpty,
              episode.plies.count <= 600,
              episode.plies.allSatisfy({ !$0.action.isEmpty && $0.action.utf8.count <= 24 }) else { return }
        switch episode.game {
        case .gomoku: gomokuEpisodes.append(episode)
        case .xiangqi: xiangqiEpisodes.append(episode)
        }
    }

    mutating func clear(game: Game) {
        switch game {
        case .gomoku: gomokuEpisodes.removeAll()
        case .xiangqi: xiangqiEpisodes.removeAll()
        }
    }

    func count(game: Game) -> Int {
        switch game {
        case .gomoku: return gomokuEpisodes.count
        case .xiangqi: return xiangqiEpisodes.count
        }
    }

    func forecast(game: Game, history: [Ply], isLegal: (String) -> Bool) -> Forecast? {
        let episodes = game == .gomoku ? gomokuEpisodes : xiangqiEpisodes
        guard !episodes.isEmpty, !history.isEmpty else { return nil }
        let contextLimit = min(6, history.count)
        var totals: [String: Int] = [:]
        var hits: [String: Int] = [:]
        for episode in episodes {
            let weight: Int
            switch episode.outcome {
            case .aiWon: weight = 7
            case .draw: weight = 2
            case .humanWon: weight = -6
            case .unfinished: weight = -3
            }
            let plies = episode.plies
            guard plies.count >= 2 else { continue }
            for i in 1..<plies.count where plies[i].actor == .ai {
                let preceding = Array(plies[..<i])
                var matched = 0
                for depth in 1...min(contextLimit, preceding.count) {
                    if preceding.suffix(depth).elementsEqual(history.suffix(depth)) {
                        matched = depth
                    }
                }
                guard matched > 0 else { continue }
                let action = plies[i].action
                totals[action, default: 0] += weight * matched
                hits[action, default: 0] += 1
            }
        }
        let eligible = totals.filter { $0.value > 0 && isLegal($0.key) }
        guard let best = eligible.max(by: { a, b in
            a.value == b.value ? a.key > b.key : a.value < b.value
        }) else { return nil }
        return Forecast(action: best.key, score: best.value,
                        matchedSequences: hits[best.key, default: 0], label: "阵法预判")
    }
}
