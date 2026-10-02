import XCTest
@testable import VeilLink

@MainActor
final class A10UltraOmegaShadowTests: XCTestCase {
    func testReleaseIdentityAndAuthorityWallAreLocked() {
        XCTAssertEqual(A10UltraOmegaRelease.chipName, "A10 Ultra Ω")
        XCTAssertEqual(A10UltraOmegaRelease.architecture, "OMEGA 96")
        XCTAssertEqual(A10UltraOmegaRelease.architectureVersion, "V0.2")
        XCTAssertEqual(A10UltraOmegaRelease.releaseStatus, "SHADOW_ACCELERATED")
        XCTAssertEqual(A10UltraOmegaRelease.productionCutover, "DENIED")
        XCTAssertFalse(A10UltraOmegaRelease.nativeIOSARM64Available)
    }

    func testIndependentGovernanceProducesAuthoritativeBudgetWithoutAppMutation() {
        let defaults = UserDefaults(suiteName: "A10Independent.\(UUID().uuidString)")!
        let selector = VeilKernelRuntimeSelector(defaults: defaults)
        selector.select(.a10Independent)
        let coordinator = A10UltraOmegaShadowCoordinator()
        let sample = coordinator.makeSharedSample(
            input: VeilA9Input(),
            hostContext: A10UltraOmegaHostContext(
                foregroundActive: true,
                systemAvailable: true,
                gameRuntimeState: "IDLE",
                activeProcessorCount: 2,
                physicalMemoryBytes: 2_000_000_000
            )
        )

        let result = coordinator.evaluateA10UltraIsolated(sample: sample, runtime: selector.beginSample())
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.decision.level, 0)
        XCTAssertEqual(result?.budget.mode, "NORMAL")
        XCTAssertEqual(coordinator.lastRuntimeSample?.divergenceClass, "A10_INDEPENDENT_GOVERNANCE")
        XCTAssertEqual(coordinator.lastRuntimeSample?.environment.mutationAuthority, 0)
    }

    func testSharedSampleHasEpochDigestAndRawInput() {
        let coordinator = A10UltraOmegaShadowCoordinator()
        let input = VeilA9Input(weakPeerCount: 1)
        let context = A10UltraOmegaHostContext(
            foregroundActive: true, systemAvailable: true, gameRuntimeState: "IDLE",
            activeProcessorCount: 4, physicalMemoryBytes: 2_000_000_000
        )
        let first = coordinator.makeSharedSample(input: input, hostContext: context)
        let second = coordinator.makeSharedSample(input: input, hostContext: context)
        XCTAssertEqual(first.epoch + 1, second.epoch)
        XCTAssertNotEqual(first.sampleID, second.sampleID)
        XCTAssertEqual(first.signalDigest.count, 64)
        XCTAssertEqual(first.rawInput, input)
    }


    func testRuntimeEpochResetIsExplicitAndObservable() {
        let coordinator = A10UltraOmegaShadowCoordinator()
        XCTAssertEqual(coordinator.runtimeEpochResetCount, 0)
        coordinator.resetRuntimeEpoch(reason: "TEST_MODE_BOUNDARY")
        XCTAssertEqual(coordinator.runtimeEpochResetCount, 1)
        XCTAssertEqual(coordinator.lastRuntimeEpochResetReason, "TEST_MODE_BOUNDARY")
    }

    func testStage0NeverPromotesUltra() {
        let coordinator = A10UltraOmegaShadowCoordinator()
        XCTAssertEqual(coordinator.state.cutoverStage, .stage0)
        XCTAssertEqual(coordinator.state.productionCutover, "DENIED")
    }

    func testD4DefinitionCatchesUltraFalseNegative() {
        let coordinator = A10UltraOmegaShadowCoordinator()
        let input = VeilA9Input(databaseIntegrity: .failed)
        let context = A10UltraOmegaHostContext(
            foregroundActive: true, systemAvailable: true, gameRuntimeState: "IDLE",
            activeProcessorCount: 4, physicalMemoryBytes: 2_000_000_000
        )
        let sample = coordinator.makeSharedSample(input: input, hostContext: context)
        let a9 = VeilA9Decision(
            light: .red, level: .l5Emergency, reasonCode: "P0_HARD_BREAK",
            healthScore: 50, riskPoints: 40, persistenceRuns: 0,
            issues: [VeilA9Issue(code: "SQLITE_INTEGRITY_FAILED", severity: .p0, source: "storage", detail: "")],
            latticeIndex: 5
        )
        let plan = VeilA9ComputePlan.bootstrap(profile: .current)
        coordinator.recordA9Primary(sample: sample, decision: a9, budget: plan, latencyNanos: 10, cpuNanos: 5)
        coordinator.evaluateA10UltraShadow(sample: sample)
        XCTAssertNotEqual(coordinator.lastComparison?.divergence, .d4)
        XCTAssertEqual(coordinator.state.productionCutover, "DENIED")
    }
}
