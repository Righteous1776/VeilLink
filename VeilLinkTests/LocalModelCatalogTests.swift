import XCTest
@testable import VeilLink

final class LocalModelCatalogTests: XCTestCase {
    func testPrimaryModelIdentityIsPinned() {
        let model = LocalModelCatalog.primary
        XCTAssertEqual(model.resourceName, "Qwen3-0.6B-Q4_0")
        XCTAssertEqual(model.quantization, "Q4_0")
        XCTAssertEqual(model.sha256.count, 64)
        XCTAssertEqual(LocalModelCatalog.qwenModelRevision.count, 40)
        XCTAssertEqual(LocalModelCatalog.llamaCPPCommit.count, 40)
    }

    func testLegacyRuntimeBudgetIsConservative() {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        let config = LlamaRuntimeConfiguration.resolved(profile: profile)
        XCTAssertLessThanOrEqual(config.contextTokens, 1_024)
        XCTAssertEqual(config.gpuLayers, 0)
        XCTAssertLessThanOrEqual(config.threads, 2)
    }
}
