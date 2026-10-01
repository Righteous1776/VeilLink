import XCTest
@testable import VeilLink

@MainActor
final class VeilLatticeKernelBridgeTests: XCTestCase {
    func testHostProfileKeepsKernelAdvisoryAndNonMutating() {
        let profile = VeilKernelHostProfile.veilLink
        XCTAssertEqual(profile.authority, .advisoryOnly)
        XCTAssertFalse(profile.canMutateTransport)
        XCTAssertFalse(profile.canMutateStorage)
        XCTAssertFalse(profile.canMutateGameState)
        XCTAssertFalse(profile.canReadSecrets)
        XCTAssertFalse(profile.allowsCloudScheduling)
        XCTAssertFalse(profile.allowsPeerComputeOffload)
        XCTAssertEqual(profile.signalBusVersion, VeilKernelSignalBus.version)
    }

    func testBridgeStartsReadyWhileA9RemainsActiveCompatibilityProfile() {
        let bridge = VeilLatticeKernelBridge()
        XCTAssertEqual(bridge.snapshot.stage, .a10IntegrationReady)
        XCTAssertEqual(bridge.snapshot.activeProfileID, VeilKernelHostProfile.veilLink.compatibilityProfileID)
        XCTAssertNil(bridge.snapshot.candidateProfileID)
    }

    func testA9SignalFrameUsesVersionedHostNamespaces() {
        let input = VeilA9Input(
            transportCoverage: .bluetoothOnly,
            bluetoothRunning: true,
            connectedPeerCount: 1,
            trackedPeerCount: 1,
            recoveringPeerCount: 0,
            weakPeerCount: 0,
            marginalPeerCount: 0,
            minimumLinkHealth: 88,
            maximumReconnectAttempt: 0,
            pendingBytes: 512,
            controlPendingPackets: 1,
            maximumStallMilliseconds: 0,
            agentUnavailable: false,
            agentCooling: false,
            agentHasFailure: false,
            thermalLevel: .nominal,
            lowPowerMode: false,
            databaseIntegrity: .ok
        )
        let frame = VeilKernelSignalFrame.fromA9(input, generatedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(frame.schemaVersion, 1)
        XCTAssertEqual(frame.profileID, "veillink.a9.compat.v1")
        XCTAssertEqual(frame.integerSignals["transport.connected_peer_count"], 1)
        XCTAssertEqual(frame.textSignals["transport.coverage"], "BLE_ONLY")
        XCTAssertEqual(frame.booleanSignals["storage.integrity_failed"], false)
    }

    func testShadowComparisonCountsOnlyUnexpectedDecisionDrift() {
        let bridge = VeilLatticeKernelBridge()
        let input = VeilA9Input()
        let baseline = VeilA9Decision.initial
        bridge.recordA9Compatibility(input: input, decision: baseline)
        bridge.beginA10ShadowValidation(candidateProfileID: "veillink.a10.compat-test")

        let matching = VeilKernelDecisionSnapshot.fromA9(baseline)
        bridge.recordA10ShadowDecision(matching)
        XCTAssertEqual(bridge.snapshot.unexpectedDecisionDiffs, 0)

        let changed = VeilKernelDecisionSnapshot(
            profileID: matching.profileID,
            light: matching.light,
            level: matching.level,
            reasonCode: "DIFFERENT",
            healthScore: matching.healthScore,
            riskBasisPoints: matching.riskBasisPoints,
            persistenceSeconds: matching.persistenceSeconds,
            latticeCell: matching.latticeCell,
            issues: matching.issues,
            preflight: matching.preflight
        )
        bridge.recordA10ShadowDecision(changed)
        XCTAssertEqual(bridge.snapshot.unexpectedDecisionDiffs, 1)
        XCTAssertEqual(bridge.snapshot.activeProfileID, VeilKernelHostProfile.veilLink.compatibilityProfileID)
    }
}
