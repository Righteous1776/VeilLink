import XCTest
@testable import VeilLink

final class A10UltraM5IntegrationTests: XCTestCase {
    @MainActor
    func testRuntimeIdentityIsM5ShadowOnly() {
        let runtime = A10UltraM5Runtime()
        XCTAssertEqual(runtime.manifest.runtimeID, "a10-ultra-omega.m5.micro-language-reasoning.ios-shadow")
        XCTAssertEqual(runtime.manifest.artifactDigest, "c5ba826dab1ebe1db02e90e8b4bfd2c060e99586413970fa3bd4d848e378a8b4")
        XCTAssertEqual(runtime.manifest.abiVersion, 1)
        XCTAssertEqual(runtime.manifest.supportedTasks, [.textGeneration, .structuredReasoning])
        XCTAssertTrue(runtime.manifest.notes.contains("SHADOW_ONLY"))
    }

    func testNativeABIIsPinned() {
        XCTAssertEqual(a10_ultra_m5_native_abi_version(), 1)
    }

    func testRawFeatureAdapterIsBoundedAndComplete() {
        var input = VeilA9Input()
        input.bluetoothRunning = true
        input.connectedPeerCount = 1
        input.trackedPeerCount = 2
        input.recoveringPeerCount = 1
        input.weakPeerCount = 1
        input.minimumLinkHealth = 28
        input.maximumReconnectAttempt = 3
        input.pendingBytes = 256 * 1_024
        input.controlPendingPackets = 12
        input.maximumStallMilliseconds = 1_800
        input.thermalLevel = .serious
        input.lowPowerMode = true
        input.databaseIntegrity = .failed

        let features = A10UltraM5FeatureAdapter.features(
            input: input,
            foregroundActive: true,
            batteryLevel: 0.35,
            agentGenerating: true,
            gameActive: true
        )
        XCTAssertEqual(features.count, 32)
        XCTAssertTrue(features.allSatisfy { (-1 ... 1).contains($0) })
    }

    @MainActor
    func testGovernanceStartsReadOnly() {
        let runtime = A10UltraM5Runtime()
        let advisor = A10UltraM5GovernanceAdvisor(runtime: runtime)
        XCTAssertEqual(advisor.snapshot.mutationAuthority, 0)
        XCTAssertEqual(advisor.snapshot.recommendation, "SHADOW_ADVISORY_ONLY")
        XCTAssertEqual(advisor.snapshot.featureAdapter, "VEILLINK_M4_PROXY_V1")
    }

    func testShadowSnapshotCarriesNoPlaintextField() {
        let snapshot = A10UltraM5ShadowCognitionSnapshot.idle
        XCTAssertEqual(snapshot.mutationAuthority, 0)
        XCTAssertEqual(snapshot.outputDigest, "-")
        XCTAssertEqual(snapshot.result, "IDLE")
    }
}
