import Foundation

@MainActor private var checks = 0
@MainActor private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}

@main struct EclipseSessionGateTests {
    @MainActor static func main() {
        typealias G = VeilEclipseTraceSessionGate
        let a = G.Ticket(sessionID: "match-A", turn: 18, generation: 1, boardFingerprint: 0xABCD)
        let staleTurn = G.Ticket(sessionID: "match-A", turn: 16, generation: 1, boardFingerprint: 0xABCD)
        let staleBoard = G.Ticket(sessionID: "match-A", turn: 18, generation: 1, boardFingerprint: 0xEEEE)
        let nextGeneration = G.Ticket(sessionID: "match-A", turn: 18, generation: 2, boardFingerprint: 0xABCD)
        let nextMatch = G.Ticket(sessionID: "match-B", turn: 18, generation: 1, boardFingerprint: 0xABCD)
        func e(_ ticket: G.Ticket, depth: Int? = 3, nodes: Int? = 100,
               origin: G.Origin = .measuredNative, final: Bool = false) -> G.PrivateEvent {
            G.PrivateEvent(ticket: ticket, origin: origin, completedDepth: depth,
                           visitedNodes: nodes, principalVariation: [67, 83, 123],
                           candidateIndices: [67, 123], analysisText: "私人候选 83", isFinal: final)
        }
        var g = G()
        check(g.accept(e(a), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "No search without begin")
        g.begin(a)
        check(g.ticket == a, "Current session established")
        check(g.accept(e(staleTurn), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Old turn rejected")
        check(g.accept(e(staleBoard), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Old board rejected")
        check(g.accept(e(nextGeneration), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Old generation rejected")
        check(g.accept(e(nextMatch), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Other match rejected")
        check(g.accept(e(a, origin: .recorded), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Recorded events rejected")
        check(g.accept(e(a, origin: .demonstration), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Demonstration events rejected")
        check(g.accept(e(a), matchIsPlaying: false, nowMilliseconds: 1000) == nil,
              "Postgame metrics rejected")
        check(g.accept(e(a, depth: nil, nodes: nil), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "No empty fabricated metrics")
        check(g.accept(e(a, depth: 0), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Depth zero rejected")
        check(g.accept(e(a, depth: 65), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Depth overflow rejected")
        check(g.accept(e(a, nodes: -1), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Negative nodes rejected")
        check(g.accept(e(a, nodes: 500_000_001), matchIsPlaying: true, nowMilliseconds: 1000) == nil,
              "Implausible nodes rejected")
        let first = g.accept(e(a), matchIsPlaying: true, nowMilliseconds: 1000)
        check(first?.completedDepth == 3 && first?.visitedNodes == 100, "First measured update")
        check(g.accept(e(a, depth: 2, nodes: 120), matchIsPlaying: true, nowMilliseconds: 1200) == nil,
              "Regressed depth rejected")
        check(g.accept(e(a, depth: 4, nodes: 99), matchIsPlaying: true, nowMilliseconds: 1200) == nil,
              "Regressed node count rejected")
        check(g.accept(e(a, depth: 4, nodes: 200), matchIsPlaying: true, nowMilliseconds: 1100) == nil,
              "8 Hz throttle")
        check(g.accept(e(a, depth: 4, nodes: 210), matchIsPlaying: true, nowMilliseconds: 900) == nil,
              "Nonmonotonic clock rejected")
        let second = g.accept(e(a, depth: 4, nodes: 240), matchIsPlaying: true, nowMilliseconds: 1125)
        check(second?.completedDepth == 4 && second?.visitedNodes == 240, "Emits at 125 ms")
        let partial = g.accept(e(a, depth: nil, nodes: 270), matchIsPlaying: true, nowMilliseconds: 1250)
        check(partial?.completedDepth == 4 && partial?.visitedNodes == 270, "Partial update preserves depth")
        let final = g.accept(e(a, depth: 5, nodes: 400, final: true), matchIsPlaying: true, nowMilliseconds: 1251)
        check(final?.completedDepth == 5 && final?.visitedNodes == 400, "Final flush bypasses throttle")
        check(g.accept(e(a, depth: 6, nodes: 600), matchIsPlaying: true, nowMilliseconds: 1400) == nil,
              "No events after final")
        g.end()
        check(g.ticket == nil, "Ended session is closed")
        check(g.accept(e(a), matchIsPlaying: true, nowMilliseconds: 1500) == nil,
              "Late callback after end rejected")
        g.begin(nextMatch)
        check(g.accept(e(nextMatch, depth: 1, nodes: 5), matchIsPlaying: true,
                       nowMilliseconds: 1501)?.visitedNodes == 5,
              "New match resets counters")
        check(G.Ticket(sessionID: "match-A", turn: 18, generation: 1,
                       boardFingerprint: 0xABCD) == a, "Stable ticket identity")
        g.begin(G.Ticket(sessionID: "", turn: 0, generation: 0, boardFingerprint: 0))
        check(g.ticket == nil, "Empty session ID rejected")
        check(VeilEclipseTierPresentation.shortName("天元 · 6×") == "天元", "V9 tier label")
        check(VeilEclipseTierPresentation.shortName("传奇 · 4×") == "传奇", "V9 second tier")
        check(VeilEclipseTierPresentation.shortName("宗师") == "宗师", "Legacy tier unchanged")
        check(VeilEclipseTierPresentation.shortName(" ") == "未设置", "Empty tier safe fallback")
        check(VeilEclipseTierPresentation.hasSearchBudgetMultiplier("棋圣 · 2×"),
              "Budget multiplier disclosed")
        check(!VeilEclipseTierPresentation.hasSearchBudgetMultiplier("进阶"),
              "No fake multiplier for old tier")
        let mirror = Mirror(reflecting: first!)
        let exposedNames = mirror.children.compactMap(\.label)
        check(exposedNames == ["completedDepth", "visitedNodes"],
              "Public output has exactly two nonspatial fields")
        print("PASS: \(checks) session-isolation, fairness and V9 tier checks")
    }
}
