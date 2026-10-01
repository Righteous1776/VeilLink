import XCTest
@testable import VeilLink

final class VeilKernelHostSafetyPolicyTests: XCTestCase {
    func testStorageP0ForcesLabFallback() {
        XCTAssertEqual(
            VeilKernelHostSafetyPolicy.fallbackReason(for: VeilA9Input(databaseIntegrity: .failed)),
            .storageP0
        )
    }

    func testCriticalThermalForcesLabFallback() {
        XCTAssertEqual(
            VeilKernelHostSafetyPolicy.fallbackReason(for: VeilA9Input(thermalLevel: .critical)),
            .thermalCritical
        )
    }

    func testOrdinaryWarningDoesNotDestroyLabExperiment() {
        XCTAssertNil(
            VeilKernelHostSafetyPolicy.fallbackReason(for: VeilA9Input(weakPeerCount: 1, thermalLevel: .fair))
        )
    }
}
