import Foundation
import JavaScriptCore

/// MIT-licensed external engine hosted in JavaScriptCore, without network,
/// subprocesses or JIT dependencies. Each JSContext stays isolated to this
/// actor and can never mutate the app's board state or learning database.
actor VeilOfflineGomokuEngine {
    static let shared = VeilOfflineGomokuEngine()

    private var context: JSContext?
    private var bootstrapFailed = false

    func chooseMove(
        in state: GomokuState,
        for player: MiniGamePlayer,
        timeLimitMilliseconds: Int,
        maxDepth: Int = 5
    ) -> GomokuBotMove? {
        guard !Task.isCancelled,
              state.currentPlayer == player,
              state.winner == nil,
              !state.isDraw else { return nil }
        guard let context = loadContext() else { return nil }
        guard let engine = context.objectForKeyedSubscript("GomokuEngine"),
              !engine.isUndefined, !engine.isNull,
              let ctor = engine.forProperty("Board"),
              let board = ctor.construct(withArguments: []) else { return nil }

        let started = Date()
        // Reconstruct a board from the authoritative Swift rule engine.
        // Incremental hashes and pattern scores are updated via Board.play().
        // The original move history is intentionally not supplied and must
        // never be inferred from the order in which occupied cells are scanned.
        for index in 0..<(GomokuState.size * GomokuState.size) {
            let stone = Int(state.value(at: index))
            if stone == 0 { continue }
            board.invokeMethod("play", withArguments: [
                index / GomokuState.size,
                index % GomokuState.size,
                stone
            ])
            if context.exception != nil { context.exception = nil; return nil }
        }

        let milliseconds = max(80, min(1_400, timeLimitMilliseconds))
        let options: [String: Any] = [
            "style": "balanced",
            "vcf": true,
            "vct": milliseconds >= 1_000,
            "maxDepth": max(2, min(8, maxDepth)),
            "vcfDepth": 10,
            "vctDepth": 4
        ]
        context.exception = nil
        let answer = engine.invokeMethod("chooseMove", withArguments: [
            board,
            player == .host ? 1 : 2,
            Double(milliseconds) / 1_000.0,
            options
        ])
        guard !Task.isCancelled,
              context.exception == nil,
              let move = answer?.forProperty("move"),
              move.isArray,
              let rawRow = move.atIndex(0), rawRow.isNumber,
              let rawColumn = move.atIndex(1), rawColumn.isNumber else { return nil }
        let row = Int(rawRow.toInt32())
        let column = Int(rawColumn.toInt32())
        guard (0..<GomokuState.size).contains(row),
              (0..<GomokuState.size).contains(column) else { return nil }
        let index = row * GomokuState.size + column
        guard state.value(at: index) == 0 else { return nil }

        let info = answer?.forProperty("info")
        let rawScore = info?.forProperty("score")?.toDouble() ?? 0
        let safeScore = rawScore.isFinite
            ? Int(max(-2_000_000_000.0, min(2_000_000_000.0, rawScore)))
            : 0
        return GomokuBotMove(
            index: index,
            score: safeScore,
            nodes: Int(info?.forProperty("nodes")?.toInt32() ?? 0),
            elapsedMilliseconds: Int(Date().timeIntervalSince(started) * 1000)
        )
    }

    private func loadContext() -> JSContext? {
        if let context { return context }
        if bootstrapFailed { return nil }
        guard let url = Bundle.main.url(
            forResource: "engine", withExtension: "js", subdirectory: "GomokuEngineV2"
        ), let source = try? String(contentsOf: url, encoding: .utf8),
           let freshContext = JSContext() else {
            bootstrapFailed = true
            return nil
        }
        freshContext.evaluateScript(source, withSourceURL: url)
        guard freshContext.exception == nil,
              let engine = freshContext.objectForKeyedSubscript("GomokuEngine"),
              !engine.isUndefined, !engine.isNull else {
            bootstrapFailed = true
            return nil
        }
        context = freshContext
        return freshContext
    }
}
