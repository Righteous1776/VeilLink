import Foundation

/// The user's live game is NEVER a coaching surface. This policy is kept
/// outside SwiftUI so privacy/safety rules are unit-testable on Linux and iOS.
/// A finished game permits a read-only replay of actual, committed moves only.
enum VeilEclipseTracePolicy {
    static let size = 15
    static let capacity = size * size

    struct PlacedMove: Sendable, Equatable {
        let index: Int
        /// 1 = black/host, 2 = white/guest.
        let stone: UInt8
        init(index: Int, stone: UInt8) {
            self.index = index
            self.stone = stone
        }
    }

    struct ReplayFrame: Sendable, Equatable {
        let cells: [UInt8]
        let lastCommittedIndex: Int?
        let committedPlyCount: Int
    }

    enum SearchOrigin: Sendable {
        case measuredEngine
        case recordedEngine
        case exampleOnly
    }

    /// Internal engine values, never handed directly to the presentation layer.
    struct RawSearchEvent: Sendable {
        let origin: SearchOrigin
        let completedDepth: Int?
        let visitedNodes: Int?
        let principalVariation: [Int]
        let consideredIndices: [Int]
        let explanation: String?
    }

    /// The only type the live SwiftUI widget will accept from a searcher.
    /// It has no coordinate-bearing fields by construction.
    struct LiveMetrics: Sendable, Equatable {
        let completedDepth: Int?
        let visitedNodes: Int?
    }

    static func liveMetrics(from event: RawSearchEvent?) -> LiveMetrics? {
        guard let event, event.origin == .measuredEngine else { return nil }
        return LiveMetrics(
            completedDepth: event.completedDepth.flatMap { (1...64).contains($0) ? $0 : nil },
            visitedNodes: event.visitedNodes.flatMap { (0...500_000_000).contains($0) ? $0 : nil }
        )
    }

    /// Sanitized public view model. During any active game, ALL coordinates,
    /// scored candidates, variations and opponent threats are withheld.
    struct PublicAnalysis: Sendable, Equatable {
        let completedDepth: Int?
        let visitedNodes: Int?
        let canReplaySpatialData: Bool
        let actualMoves: [Int]
        let explanation: String?
    }

    static func publicAnalysis(
        from event: RawSearchEvent?,
        matchFinished: Bool,
        separateReadOnlyPanel: Bool,
        verifiedReplay: [ReplayFrame]
    ) -> PublicAnalysis {
        guard let event, event.origin != .exampleOnly else {
            return PublicAnalysis(completedDepth: nil, visitedNodes: nil,
                                  canReplaySpatialData: false,
                                  actualMoves: [], explanation: nil)
        }
        let finishedAndVerified = matchFinished && separateReadOnlyPanel && !verifiedReplay.isEmpty
        // Recorded/example events are never passed off as live engine progress.
        let depth = event.origin == .measuredEngine
            ? event.completedDepth.flatMap { (1...64).contains($0) ? $0 : nil } : nil
        let nodes = event.origin == .measuredEngine
            ? event.visitedNodes.flatMap { (0...500_000_000).contains($0) ? $0 : nil } : nil
        // Never display raw PV/candidate coordinates from a still-running game.
        // Even after the game, replay ONLY actual played moves, not guesses.
        let replayedMoves = finishedAndVerified
            ? verifiedReplay.compactMap(\.lastCommittedIndex) : []
        return PublicAnalysis(completedDepth: depth, visitedNodes: nodes,
                              canReplaySpatialData: finishedAndVerified,
                              actualMoves: replayedMoves,
                              explanation: nil) // Unreviewed private search text is never a public hint.
    }

    /// Replay is reconstructed from the saved match journal only after match
    /// completion. It validates turn order, duplicate cells, terminal moves,
    /// and that the final board matches the authoritative GomokuState.
    static func replayFrames(
        _ moves: [PlacedMove],
        matchFinished: Bool,
        separateReadOnlyPanel: Bool,
        expectedFinalBoard: [UInt8]? = nil
    ) -> [ReplayFrame] {
        guard matchFinished, separateReadOnlyPanel,
              !moves.isEmpty, moves.count <= capacity else { return [] }
        var board = [UInt8](repeating: 0, count: capacity)
        var frames: [ReplayFrame] = [ReplayFrame(cells: board, lastCommittedIndex: nil, committedPlyCount: 0)]
        var next: UInt8 = 1
        for (offset, move) in moves.enumerated() {
            guard (0..<capacity).contains(move.index), move.stone == next,
                  board[move.index] == 0 else { return [] }
            board[move.index] = move.stone
            frames.append(ReplayFrame(cells: board, lastCommittedIndex: move.index,
                                      committedPlyCount: offset + 1))
            if hasFive(board, through: move.index, stone: next), offset != moves.count - 1 {
                return [] // A valid completed match has no moves after a win.
            }
            next = next == 1 ? 2 : 1
        }
        if let expectedFinalBoard, expectedFinalBoard != board { return [] }
        return frames
    }

    private static func hasFive(_ board: [UInt8], through index: Int, stone: UInt8) -> Bool {
        let r = index / size, c = index % size
        for (dr, dc) in [(0,1), (1,0), (1,1), (1,-1)] {
            var length = 1
            for direction in [-1,1] {
                var rr = r + dr * direction, cc = c + dc * direction
                while (0..<size).contains(rr), (0..<size).contains(cc),
                      board[rr * size + cc] == stone {
                    length += 1
                    rr += dr * direction
                    cc += dc * direction
                }
            }
            if length >= 5 { return true }
        }
        return false
    }
}
