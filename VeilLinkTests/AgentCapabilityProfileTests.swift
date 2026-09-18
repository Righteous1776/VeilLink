import XCTest
@testable import VeilLink

final class AgentCapabilityProfileTests: XCTestCase {
    func testLegacyProfilesUnloadAggressively() {
        for label in ["SE1-LOW", "LEGACY-COMPACT"] {
            let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: label)
            XCTAssertEqual(profile.tier, .legacyA10)
            XCTAssertTrue(profile.unloadOnBackground)
            XCTAssertTrue(profile.unloadOnMemoryPressure)
            XCTAssertLessThanOrEqual(profile.maxNewTokens, 96)
        }
    }

    func testHighProfileKeepsLargerLocalBudget() {
        let high = AgentCapabilityProfile.profile(devicePerformanceLabel: "13PRO-HIGH")
        let legacy = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        XCTAssertEqual(high.tier, .high)
        XCTAssertGreaterThan(high.recentMessageLimit, legacy.recentMessageLimit)
        XCTAssertGreaterThan(high.maxNewTokens, legacy.maxNewTokens)
        XCTAssertFalse(high.unloadOnBackground)
    }
}
