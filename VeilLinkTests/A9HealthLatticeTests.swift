import XCTest
@testable import VeilLink

final class A9HealthLatticeTests: XCTestCase {
    func testTransportRollupIncludesLANHealthAndQueuePressure() {
        let readyID = UUID()
        let recoveringID = UUID()
        let rollup = VeilTransportHealthRollup.make(
            bluetoothRunning: true,
            bluetooth: [],
            lanRunning: true,
            lan: [
                LANTurboLinkSnapshot(
                    id: readyID,
                    role: .outgoing,
                    endpointDescription: "peer-ready",
                    isReady: true,
                    pendingFrames: 2,
                    pendingBytes: 4_096
                ),
                LANTurboLinkSnapshot(
                    id: recoveringID,
                    role: .incoming,
                    endpointDescription: "peer-recovering",
                    isReady: false,
                    pendingFrames: 1,
                    pendingBytes: 2_048
                )
            ]
        )

        XCTAssertEqual(rollup.coverage, .multiTransport)
        XCTAssertEqual(rollup.connectedLinkCount, 1)
        XCTAssertEqual(rollup.trackedLinkCount, 2)
        XCTAssertEqual(rollup.recoveringLinkCount, 1)
        XCTAssertEqual(rollup.pendingBytes, 6_144)
    }

    func testA9LatticeContainsExactly144States() {
        XCTAssertEqual(VeilA9Lattice.cells.count, 144)
        XCTAssertEqual(Set((0..<144).map { $0 }).count, 144)
    }

    func testGreenNormalStaysL0() {
        let packet = VeilA9Packet(
            light: .green, p0: 0, p1: 0, p2: 0, p3: 0,
            riskBP: 0, persistenceRuns: 0, blocker: false, healthBP: 1_000, issues: []
        )
        let decision = VeilA9Lattice.decide(packet)
        XCTAssertEqual(decision.level, .l0Observe)
        XCTAssertEqual(decision.reasonCode, "GREEN_NORMAL")
    }

    func testPersistentYellowEscalatesToL2() {
        let packet = VeilA9Packet(
            light: .yellow, p0: 0, p1: 0, p2: 1, p3: 0,
            riskBP: 400,
            persistenceRuns: VeilA9Lattice.persistentDurationThresholdSeconds,
            blocker: false,
            healthBP: 900,
            issues: []
        )
        XCTAssertEqual(VeilA9Lattice.decide(packet).level, .l2Review)
    }

    func testRedBlockerIsL4AndP0IsAlwaysL5() {
        let blocker = VeilA9Packet(
            light: .red, p0: 0, p1: 1, p2: 0, p3: 0,
            riskBP: 1_200, persistenceRuns: 1, blocker: true, healthBP: 700, issues: []
        )
        XCTAssertEqual(VeilA9Lattice.decide(blocker).level, .l4HoldRecommendation)

        let p0 = VeilA9Packet(
            light: .red, p0: 1, p1: 0, p2: 0, p3: 0,
            riskBP: 4_000, persistenceRuns: 0, blocker: false, healthBP: 500, issues: []
        )
        XCTAssertEqual(VeilA9Lattice.decide(p0).level, .l5Emergency)
        XCTAssertEqual(VeilA9Lattice.decide(p0).reasonCode, "P0_HARD_BREAK")
    }

    func testClassifierDetectsStorageP0AndTransportPressure() {
        let input = VeilA9Input(
            bluetoothRunning: true,
            connectedPeerCount: 1,
            trackedPeerCount: 1,
            recoveringPeerCount: 1,
            weakPeerCount: 1,
            marginalPeerCount: 0,
            minimumLinkHealth: 18,
            maximumReconnectAttempt: 7,
            pendingBytes: 3 * 1_024 * 1_024,
            controlPendingPackets: 80,
            maximumStallMilliseconds: 25_000,
            agentUnavailable: true,
            agentCooling: false,
            agentHasFailure: true,
            thermalLevel: .serious,
            lowPowerMode: true,
            databaseIntegrity: .failed
        )
        let packet = VeilA9Classifier.makePacket(input: input, persistenceRuns: 3)
        XCTAssertEqual(packet.light, .red)
        XCTAssertGreaterThan(packet.p0, 0)
        XCTAssertTrue(packet.blocker)
        XCTAssertTrue(packet.issues.contains { $0.code == "SQLITE_INTEGRITY_FAILED" })
        XCTAssertTrue(packet.issues.contains { $0.code == "CONTROL_QUEUE_STALLED" })
    }

    func testHealthyInputHasNoIssues() {
        let packet = VeilA9Classifier.makePacket(input: VeilA9Input(), persistenceRuns: 0)
        XCTAssertEqual(packet.light, .green)
        XCTAssertEqual(packet.healthBP, 1_000)
        XCTAssertTrue(packet.issues.isEmpty)
    }
    func testA9IndexAxesRoundTripAcrossAll144States() {
        for light in 0..<3 {
            for p0 in 0..<2 {
                for p1 in 0..<3 {
                    for blocker in 0..<2 {
                        for persistent in 0..<2 {
                            for redRisk in 0..<2 {
                                let index = VeilA9Lattice.index(
                                    light: light,
                                    hasP0: p0 == 1,
                                    p1Count: p1,
                                    blocker: blocker == 1,
                                    persistent: persistent == 1,
                                    redRisk: redRisk == 1
                                )
                                let axes = VeilA9Lattice.axes(for: index)
                                XCTAssertEqual(axes?.light.rawValue, light)
                                XCTAssertEqual(axes?.hasP0, p0 == 1)
                                XCTAssertEqual(axes?.p1Bucket, p1)
                                XCTAssertEqual(axes?.blocker, blocker == 1)
                                XCTAssertEqual(axes?.persistent, persistent == 1)
                                XCTAssertEqual(axes?.redRisk, redRisk == 1)
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testPersistenceUsesElapsedTimeNotCallbackVolume() {
        let monitor = VeilA9HealthMonitor()
        let base = Date(timeIntervalSince1970: 1_000)
        let yellow = VeilA9Input(weakPeerCount: 1)

        monitor.evaluate(yellow, now: base, uptime: 100)
        for _ in 0..<100 {
            monitor.evaluate(yellow, now: base.addingTimeInterval(1), uptime: 101)
        }
        XCTAssertEqual(monitor.decision.persistenceSeconds, 1)
        XCTAssertEqual(monitor.decision.level, .l1Advisory)

        monitor.evaluate(yellow, now: base.addingTimeInterval(31), uptime: 131)
        XCTAssertEqual(monitor.decision.persistenceSeconds, 31)
        XCTAssertEqual(monitor.decision.level, .l2Review)

        monitor.evaluate(VeilA9Input(), now: base.addingTimeInterval(32), uptime: 132)
        XCTAssertEqual(monitor.decision.persistenceSeconds, 0)
        XCTAssertEqual(monitor.decision.level, .l0Observe)
    }

    func testPersistentThresholdRepresentsSeconds() {
        XCTAssertEqual(VeilA9Lattice.persistentDurationThresholdSeconds, 30)
        XCTAssertEqual(VeilA9Lattice.persistentRunThreshold, 30)
    }

}
