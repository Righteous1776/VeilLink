import XCTest
@testable import VeilLink

final class A9HealthLatticeTests: XCTestCase {
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
            riskBP: 400, persistenceRuns: 3, blocker: false, healthBP: 900, issues: []
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

}
