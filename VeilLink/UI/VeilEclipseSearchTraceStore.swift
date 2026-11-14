import Foundation

/// Live, validated, voluntarily visible AI-search branches. Not human coaching.
/// This gate has zero influence on move ordering, scores, or time budgets.
/// Session token invalidation also drops late callbacks from cancelled workers.
final class VeilEclipseSearchTraceStore: @unchecked Sendable {
    struct Branch: Equatable, Sendable {
        let indices: [Int]       // only positions the native search actually applied
        let exploredNodes: Int   // real cumulative node counter, not a probability
        let serial: UInt64
        let emittedAtUptime: TimeInterval
    }
    private let lock = NSLock()
    private var session: String?
    private var token: UUID?
    private var turn: Int = -1
    private var root: GomokuState?
    private var stored: [Branch] = []
    private var serial: UInt64 = 0
    private var lastTime: TimeInterval = -1

    @discardableResult
    func begin(sessionID: String, board: GomokuState) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        // Invalid attempts must revoke any prior session, never retain stale
        // exploration events after a restart or damaged game restoration.
        session = nil
        token = nil
        turn = -1
        root = nil
        stored = []
        serial = 0
        lastTime = -1
        guard !sessionID.isEmpty, board.winner == nil, !board.isDraw else { return nil }
        session = sessionID
        let issued = UUID()
        token = issued
        turn = board.moveCount
        root = board
        return issued
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        session = nil
        token = nil
        turn = -1
        root = nil
        stored = []
        serial = 0
        lastTime = -1
    }

    /// Called only from an actual GomokuBot exploration branch. At most 20 events/s.
    /// Returns false if the path is stale, fabricated, illegal, or out of turn.
    @discardableResult
    func record(_ indices: [Int], nodes: Int, token expected: UUID) -> Bool {
        guard (1...3).contains(indices.count), (1...2_000_000_000).contains(nodes) else { return false }
        lock.lock(); defer { lock.unlock() }
        guard expected == token, let root else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= lastTime, nodes >= (stored.last?.exploredNodes ?? 0) else { return false }
        let withinThrottle = lastTime >= 0 && now - lastTime < 0.05
        let previous = stored.last
        let deeperSameRoot = withinThrottle && previous != nil
            && previous!.indices.first == indices.first
            && indices.count > previous!.indices.count
        // Reject 99% of super-fast events before board replay/copy.
        if withinThrottle && !deeperSameRoot { return false }
        var test = root
        for index in indices {
            guard (0..<225).contains(index),
                  test.apply(index: index, actor: test.currentPlayer) else { return false }
        }
        if deeperSameRoot, let previous {
            stored[stored.count - 1] = Branch(
                indices: indices, exploredNodes: nodes,
                serial: previous.serial, emittedAtUptime: now
            )
            return true
        }
        serial &+= 1
        stored.append(Branch(indices: indices, exploredNodes: nodes, serial: serial, emittedAtUptime: now))
        if stored.count > 14 { stored.removeFirst(stored.count - 14) }
        lastTime = now
        return true
    }

    /// No branch is visible outside the exact AI turn that produced it.
    func snapshot(sessionID requestedSession: String, turn requestedTurn: Int,
                  playing: Bool, aiThinking: Bool) -> [Branch] {
        lock.lock(); defer { lock.unlock() }
        guard playing, aiThinking, token != nil,
              requestedSession == session, requestedTurn == turn else { return [] }
        return stored
    }
}
