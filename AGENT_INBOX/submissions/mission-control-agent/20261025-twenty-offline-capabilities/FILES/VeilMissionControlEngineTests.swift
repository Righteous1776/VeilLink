import XCTest
@testable import VeilLink

final class VeilMissionControlEngineTests: XCTestCase {
    func testEveryFeatureHasAResult() {
        let all = VeilMissionControlEngine.analyzeAll(VeilMissionScenario.healthy.snapshot)
        XCTAssertEqual(VeilMissionFeature.allCases.count, 20)
        XCTAssertEqual(all.count, 20)
        XCTAssertEqual(Set(all.map(\.id)).count, 20)
        XCTAssertTrue(all.allSatisfy { !$0.headline.isEmpty && !$0.explanation.isEmpty })
    }

    func testRouteShortestAndAlternate() {
        let s = VeilMissionScenario.healthy.snapshot
        let primary = VeilMissionControlEngine.shortestRoute(s.edges, source: "self", destination: "target")
        XCTAssertEqual(primary?.0, ["self", "P1", "target"])
        XCTAssertEqual(primary?.1, 4)
        let secondary = VeilMissionControlEngine.shortestRoute(s.edges, source: "self",
            destination: "target", avoiding: ["P1"])
        XCTAssertEqual(secondary?.0, ["self", "P2", "target"])
        XCTAssertNil(VeilMissionControlEngine.shortestRoute([], source: "self", destination: "target"))
    }

    func testRejectsInvalidGraphCostsAndLoops() {
        let invalid = [
            VeilMissionEdge(from: "A", to: "B", cost: -.infinity),
            VeilMissionEdge(from: "A", to: "A", cost: -1)
        ]
        XCTAssertNil(VeilMissionControlEngine.shortestRoute(invalid, source: "A", destination: "B"))
        XCTAssertEqual(
            VeilMissionControlEngine.shortestRoute([], source: "A", destination: "A")?.0, ["A"])
    }

    func testFailClosedWhenDatabaseKeyIsUnavailable() {
        let report = VeilMissionControlEngine.analyze(.keyReadiness,
            snapshot: VeilMissionScenario.recovery.snapshot)
        XCTAssertEqual(report.severity, .blocked)
        XCTAssertEqual(report.value, "拒绝重置")
    }

    func testWeakLinkIsNotTreatedAsReadyForFullCapabilities() {
        let s = VeilMissionScenario.degraded.snapshot
        XCTAssertNotEqual(VeilMissionControlEngine.analyze(.linkHealth, snapshot: s).severity, .normal)
        XCTAssertEqual(VeilMissionControlEngine.analyze(.capabilityFallback, snapshot: s).severity, .caution)
        XCTAssertEqual(VeilMissionControlEngine.analyze(.transportSelection, snapshot: s).value, "BLE")
    }

    func testRecoveryDoesNotPromiseCompletedIntegrity() {
        let report = VeilMissionControlEngine.analyze(.transferRecovery,
            snapshot: VeilMissionScenario.recovery.snapshot)
        XCTAssertTrue(report.explanation.contains("认证"))
        XCTAssertTrue(report.value.contains("待验证"))
    }

    func testReplaySequencesAndTouchOcclusion() {
        let healthy = VeilMissionScenario.healthy.snapshot
        let poor = VeilMissionScenario.degraded.snapshot
        XCTAssertEqual(VeilMissionControlEngine.analyze(.replayGuard, snapshot: healthy).severity, .normal)
        XCTAssertEqual(VeilMissionControlEngine.analyze(.replayGuard, snapshot: poor).severity, .caution)
        XCTAssertEqual(VeilMissionControlEngine.analyze(.touchOcclusion, snapshot: poor).value, "1 处")
    }

    func testThermalPrivacyBatteryWarnings() {
        let poor = VeilMissionScenario.degraded.snapshot
        for feature in [VeilMissionFeature.thermalGuard, .batteryReserve, .privacyFootprint] {
            XCTAssertEqual(VeilMissionControlEngine.analyze(feature, snapshot: poor).severity, .caution)
        }
    }

    func testQueueAndPacketMath() {
        let healthy = VeilMissionScenario.healthy.snapshot
        XCTAssertEqual(VeilMissionControlEngine.analyze(.packetSizing, snapshot: healthy).value, "182 B")
        XCTAssertEqual(VeilMissionControlEngine.analyze(.congestionControl, snapshot: healthy).value, "8 → 9")
        XCTAssertEqual(VeilMissionControlEngine.analyze(.retryPacing, snapshot: healthy).value, "2 s")
    }

    func testDeterministicAcrossRepeatedRuns() {
        let s = VeilMissionScenario.degraded.snapshot
        XCTAssertEqual(VeilMissionControlEngine.analyzeAll(s), VeilMissionControlEngine.analyzeAll(s))
    }
}
