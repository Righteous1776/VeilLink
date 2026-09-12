import XCTest
@testable import VeilLink

final class DevicePerformancePolicyTests: XCTestCase {
    func testSE1UsesMostConstrainedProfile() {
        let profile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone8,4", osMajorVersion: 15)
        XCTAssertEqual(profile.label, "SE1-LOW")
        XCTAssertEqual(profile.messageWindowInitial, 48)
        XCTAssertEqual(profile.transferVisualComplexity, .minimal)
        XCTAssertFalse(profile.shouldPrecomputeTransferShards)
    }

    func testIPhone7UsesLegacyBalancedProfile() {
        let profile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone9,1", osMajorVersion: 15)
        XCTAssertEqual(profile.label, "LEGACY-COMPACT")
        XCTAssertEqual(profile.imagePreviewMaxPixelSize, 768)
        XCTAssertEqual(profile.transferVisualComplexity, .balanced)
    }

    func testSE2UsesBalancedModernProfile() {
        let profile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone12,8", osMajorVersion: 15)
        XCTAssertEqual(profile.label, "SE2-BALANCED")
        XCTAssertEqual(profile.messageWindowInitial, 120)
        XCTAssertTrue(profile.shouldPrecomputeTransferShards)
    }

    func testIPhone13ProGetsHighPerformanceBudget() {
        let profile = DevicePerformancePolicy.profile(machineIdentifier: "iPhone14,2", osMajorVersion: 18)
        XCTAssertEqual(profile.label, "13PRO-HIGH")
        XCTAssertEqual(profile.messageWindowInitial, 180)
        XCTAssertGreaterThan(profile.imagePreviewCacheBytes, DevicePerformanceProfile.genericModern.imagePreviewCacheBytes)
    }

    func testIPadAir4ProfileIsTrackedButNotUIOptimizedHere() {
        let profile = DevicePerformancePolicy.profile(machineIdentifier: "iPad13,1", osMajorVersion: 18)
        XCTAssertEqual(profile.label, "AIR4-DEFERRED-UI")
    }
}
