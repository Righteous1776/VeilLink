import Foundation
import XCTest

/// Proposed XCTest; must be run on Apple CI after integration.
final class EclipseR14MeasuredTelemetryTests: XCTestCase {
    private func ticket(generation: UInt64 = 1, turn: Int = 6, fingerprint: UInt64 = 90210)
        -> VeilEclipseTraceSessionGate.Ticket {
        .init(sessionID: "match-1", turn: turn, generation: generation,
              boardFingerprint: fingerprint)
    }
    private func event(_ t: VeilEclipseTraceSessionGate.Ticket,
                       origin: VeilEclipseTraceSessionGate.Origin = .measuredNative,
                       depth: Int? = 3, nodes: Int? = 150, final: Bool = false)
        -> VeilEclipseTraceSessionGate.PrivateEvent {
        .init(ticket: t, origin: origin, completedDepth: depth,
              visitedNodes: nodes, principalVariation: [112, 113, 114],
              candidateIndices: [125, 130], analysisText: "private root",
              isFinal: final)
    }
    func testMeasuredOnlyPublicResult() {
        var gate = VeilEclipseTraceSessionGate()
        let t = ticket(); gate.begin(t)
        let safe = gate.accept(event(t), matchIsPlaying: true, nowMilliseconds: 1000)
        XCTAssertEqual(safe?.completedDepth, 3)
        XCTAssertEqual(safe?.visitedNodes, 150)
    }
    func testWrongOriginsAndGameOverRejected() {
        var gate = VeilEclipseTraceSessionGate()
        let t = ticket(); gate.begin(t)
        XCTAssertNil(gate.accept(event(t, origin: .recorded), matchIsPlaying: true, nowMilliseconds: 1000))
        XCTAssertNil(gate.accept(event(t, origin: .demonstration), matchIsPlaying: true, nowMilliseconds: 1001))
        XCTAssertNil(gate.accept(event(t), matchIsPlaying: false, nowMilliseconds: 1002))
        XCTAssertNotNil(gate.accept(event(t), matchIsPlaying: true, nowMilliseconds: 1003))
    }
    func testSessionTurnGenerationFingerprintAndCancel() {
        var gate = VeilEclipseTraceSessionGate()
        let old = ticket(), new = ticket(generation: 2, turn: 7, fingerprint: 20267)
        gate.begin(old); gate.begin(new)
        XCTAssertNil(gate.accept(event(old), matchIsPlaying: true, nowMilliseconds: 1000))
        XCTAssertNil(gate.accept(event(ticket(generation: 2, turn: 6, fingerprint: 20267)),
                                 matchIsPlaying: true, nowMilliseconds: 1000))
        XCTAssertNil(gate.accept(event(ticket(generation: 2, turn: 7, fingerprint: 555)),
                                 matchIsPlaying: true, nowMilliseconds: 1000))
        XCTAssertNotNil(gate.accept(event(new), matchIsPlaying: true, nowMilliseconds: 1000))
        gate.end()
        XCTAssertNil(gate.accept(event(new), matchIsPlaying: true, nowMilliseconds: 1100))
    }
    func testEightHertzAndMonotonicCounters() {
        var gate = VeilEclipseTraceSessionGate()
        let t = ticket(); gate.begin(t)
        XCTAssertNotNil(gate.accept(event(t, depth: 1, nodes: 2), matchIsPlaying: true, nowMilliseconds: 1000))
        XCTAssertNil(gate.accept(event(t, depth: 2, nodes: 12), matchIsPlaying: true, nowMilliseconds: 1100))
        XCTAssertNotNil(gate.accept(event(t, depth: 3, nodes: 20), matchIsPlaying: true, nowMilliseconds: 1125))
        XCTAssertNil(gate.accept(event(t, depth: 2, nodes: 21), matchIsPlaying: true, nowMilliseconds: 1251))
        XCTAssertNil(gate.accept(event(t, depth: 4, nodes: 10), matchIsPlaying: true, nowMilliseconds: 1251))
        XCTAssertNil(gate.accept(event(t, depth: 4, nodes: 100), matchIsPlaying: true, nowMilliseconds: 1100))
    }
    func testFinalSealsSession() {
        var gate = VeilEclipseTraceSessionGate()
        let t = ticket(); gate.begin(t)
        XCTAssertNotNil(gate.accept(event(t, depth: 3, nodes: 100, final: true),
                                    matchIsPlaying: true, nowMilliseconds: 1000))
        XCTAssertNil(gate.accept(event(t, depth: 4, nodes: 200),
                                 matchIsPlaying: true, nowMilliseconds: 1300))
    }
    func testInvalidCountersCannotRender() {
        var gate = VeilEclipseTraceSessionGate()
        let t = ticket(); gate.begin(t)
        XCTAssertNil(gate.accept(event(t, depth: 65, nodes: 1),
                                 matchIsPlaying: true, nowMilliseconds: 1000))
        XCTAssertNil(gate.accept(event(t, depth: 1, nodes: 500_000_001),
                                 matchIsPlaying: true, nowMilliseconds: 1001))
    }
}
