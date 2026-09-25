import XCTest
@testable import VeilLink

final class RuntimeMaintenanceOptimizationR12Tests: XCTestCase {
    func testLegacyMaintenanceUsesLowerDutyCycleThanHighTier() {
        let legacy = VeilRuntimeMaintenanceTuning.resolved(performanceLabel: "LEGACY-COMPACT")
        let high = VeilRuntimeMaintenanceTuning.resolved(performanceLabel: "13PRO-HIGH")
        XCTAssertGreaterThan(legacy.outboundRetryIntervalNanoseconds, high.outboundRetryIntervalNanoseconds)
        XCTAssertGreaterThan(legacy.bleConnectedMaintenanceNanoseconds, high.bleConnectedMaintenanceNanoseconds)
        XCTAssertGreaterThan(legacy.rssiPollInterval, high.rssiPollInterval)
        XCTAssertGreaterThan(legacy.jitterStatsPublishInterval, high.jitterStatsPublishInterval)
    }

    func testQueuedTransportMaintenanceRemainsMoreResponsiveThanIdle() {
        for label in ["LEGACY-COMPACT", "MODERN", "13PRO-HIGH"] {
            let tuning = VeilRuntimeMaintenanceTuning.resolved(performanceLabel: label)
            XCTAssertLessThan(tuning.bleQueuedMaintenanceNanoseconds, tuning.bleConnectedMaintenanceNanoseconds)
            XCTAssertLessThan(tuning.bleConnectedMaintenanceNanoseconds, tuning.bleIdleMaintenanceNanoseconds)
        }
    }
}
