import XCTest
@testable import VeilLink

@MainActor
final class VeilKernelRuntimeSelectorTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "VeilKernelRuntimeSelectorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testDualShadowRunsBothButA9KeepsProductionAuthority() {
        let selector = VeilKernelRuntimeSelector(defaults: makeDefaults())
        selector.select(.dualShadow)
        let env = selector.beginSample()
        XCTAssertTrue(env.a9EvaluationEnabled)
        XCTAssertTrue(env.ultraEvaluationEnabled)
        XCTAssertEqual(env.productionAuthority, "A9_PRIMARY")
        XCTAssertEqual(env.mutationAuthority, 0)
        XCTAssertEqual(env.productionCutover, "DENIED")
    }

    func testA9OnlyDisablesUltraForBaselineRuns() {
        let selector = VeilKernelRuntimeSelector(defaults: makeDefaults())
        selector.select(.a9Only)
        let env = selector.beginSample()
        XCTAssertTrue(env.a9EvaluationEnabled)
        XCTAssertFalse(env.ultraEvaluationEnabled)
        XCTAssertEqual(env.productionAuthority, "A9_PRIMARY")
    }

    func testA10OnlyLabDisablesA9ButDoesNotGrantProductionAuthority() {
        let selector = VeilKernelRuntimeSelector(defaults: makeDefaults())
        selector.select(.a10OnlyLab)
        let env = selector.beginSample()
        XCTAssertFalse(env.a9EvaluationEnabled)
        XCTAssertTrue(env.ultraEvaluationEnabled)
        XCTAssertEqual(env.productionAuthority, "HOST_FROZEN_BASELINE")
        XCTAssertEqual(env.mutationAuthority, 0)
        XCTAssertEqual(env.fallbackPolicy, "AUTO_EXIT_TO_A9_ON_ULTRA_FAILURE_OR_RESTART")
    }

    func testA10OnlyLabIsNotPersistedAcrossRestart() {
        let defaults = makeDefaults()
        let selector = VeilKernelRuntimeSelector(defaults: defaults)
        selector.select(.dualShadow)
        selector.select(.a10OnlyLab)
        let restarted = VeilKernelRuntimeSelector(defaults: defaults)
        XCTAssertEqual(restarted.mode, .a9Only)
        XCTAssertEqual(restarted.lastFallbackReason, "LAB_MODE_RESTART_FALLBACK")
    }

    func testModeChangeCreatesNewEnvironmentEpochAndSession() {
        let selector = VeilKernelRuntimeSelector(defaults: makeDefaults())
        let before = selector.snapshot()
        selector.select(.a9Only)
        let after = selector.snapshot()
        XCTAssertGreaterThan(after.modeEpoch, before.modeEpoch)
        XCTAssertNotEqual(after.modeSessionID, before.modeSessionID)
    }
}
