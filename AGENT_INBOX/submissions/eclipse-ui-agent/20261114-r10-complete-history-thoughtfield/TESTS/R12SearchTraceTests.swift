import Foundation

@main struct TraceStoreTests {
    static func main() {
        var checks = 0
        func check(_ value: Bool, _ label: String) {
            checks += 1
            precondition(value, "failed: \(label)")
        }
        let store = VeilEclipseSearchTraceStore()
        let board = GomokuState()
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true).isEmpty, "no early read")
        guard let t = store.begin(sessionID: "s", board: board) else { fatalError("begin") }
        check(store.record([112], nodes: 1, token: t), "real first move")
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true).count == 1, "real snapshot")
        check(store.record([112, 113], nodes: 2, token: t), "real reply promotes line under throttle")
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true).last?.indices == [112,113], "line connects 2 ghosts")
        check(store.snapshot(sessionID: "s", turn: 1, playing: true, aiThinking: true).isEmpty, "reject future turn")
        check(store.snapshot(sessionID: "old", turn: 0, playing: true, aiThinking: true).isEmpty, "reject old session")
        check(store.snapshot(sessionID: "s", turn: 0, playing: false, aiThinking: true).isEmpty, "reject finished")
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: false).isEmpty, "reject human turn")
        check(!store.record([225], nodes: 2, token: t), "reject out of bounds")
        check(!store.record([-1], nodes: 2, token: t), "reject negative")
        check(!store.record([112,112], nodes: 2, token: t), "reject duplicate")
        check(!store.record([112, 113, 114, 115], nodes: 2, token: t), "reject 4ply")
        check(!store.record([], nodes: 2, token: t), "reject empty")
        check(!store.record([100], nodes: 0, token: t), "reject zero nodes")
        check(!store.record([100], nodes: -1, token: t), "reject negative nodes")
        check(!store.record([100], nodes: 2, token: UUID()), "reject foreign token")
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true).first?.indices == [112,113], "no invalid contamination")
        store.clear()
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true).isEmpty, "clear")
        check(!store.record([100], nodes: 2, token: t), "late callback rejected")
        guard let new = store.begin(sessionID: "s", board: board) else { fatalError("rebegin") }
        check(new != t, "new token")
        check(!store.record([100], nodes: 3, token: t), "prior callback stale")
        check(store.record([112,113,114], nodes: 4, token: new), "legal 3ply")
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true).first?.indices.count == 3, "3ply available")
        let before = store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true)
        check(!store.record([112], nodes: 8, token: new), "rate limited")
        check(store.snapshot(sessionID: "s", turn: 0, playing: true, aiThinking: true) == before, "rate limit not mutating")
        print("PASS: \(checks) search trace invariants")
    }
}
