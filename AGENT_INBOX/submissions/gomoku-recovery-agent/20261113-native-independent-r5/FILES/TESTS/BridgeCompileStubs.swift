import Foundation

enum MiniGamePlayer: Sendable { case host, guest }
struct GomokuState: Sendable {
    var board: [Int8] = [Int8](repeating: 0, count: 225)
    var currentPlayer: MiniGamePlayer = .host
    var winner: MiniGamePlayer? = nil
    var isDraw = false
    static let size = 15
    func value(at index: Int) -> Int8 { board[index] }
    mutating func apply(index: Int, actor: MiniGamePlayer) -> Bool {
        guard winner == nil && !isDraw && currentPlayer == actor && (0..<225).contains(index) && board[index] == 0 else { return false }
        board[index] = actor == .host ? 1 : 2
        currentPlayer = actor == .host ? .guest : .host
        return true
    }
}
struct GomokuBotBudget {
    let candidateRadius: Int
    let rootCandidateLimit: Int
    let continuationCandidateLimit: Int
    let timeLimitMilliseconds: Int
}
struct GomokuBotMove { let index: Int; let score: Int; let nodes: Int; let elapsedMilliseconds: Int }
struct AdaptiveBoardPosition { static func gomoku(_ state: GomokuState) -> Self { .init() } }
struct AdaptiveBoardLearningSnapshot {
    func bonus(position: AdaptiveBoardPosition, action: String) -> Int { 0 }
    func rootAdjustment(action: String) -> Int { 0 }
}
struct GomokuFormationPreference {
    static func opponentHasImmediateWin(in state: GomokuState, player: MiniGamePlayer) -> Bool { false }
    func bonus(index: Int, state: GomokuState, player: MiniGamePlayer, urgentDefense: Bool) -> Int { 0 }
}
