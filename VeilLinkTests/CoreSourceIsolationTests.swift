import XCTest
@testable import VeilLink

final class CoreSourceIsolationTests: XCTestCase {
    @MainActor
    func testCoreFactoryUsesZeroWeightVeilTalkRuntime() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        let runtime = LocalTextModelRuntimeFactory.make(profile: profile)
        XCTAssertTrue(runtime is VeilTalkLiteRuntime)
        XCTAssertFalse(LocalTextModelRuntimeFactory.isRealLocalInferenceCompiled)
        XCTAssertEqual(LocalTextModelRuntimeFactory.backendName, "VeilTalk Lite")
        XCTAssertEqual(runtime.manifest?.byteCount, 0)
    }

    @MainActor
    func testCoreGovernorCannotEnableExperimentalNeuralRuntime() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let governor = VeilA9ComputeGovernor(profile: profile, logicalProcessorCount: 6)
        governor.setExperimentalCoreEnabled(true)
        XCTAssertFalse(governor.experimentalCoreEnabled)
    }
}
