import XCTest
@testable import VeilLink

final class RenderCompatibilityPolicyTests: XCTestCase {
    func testIPhone7OnIOS15UsesLegacyCompositor() {
        XCTAssertTrue(RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone9,1", osMajorVersion: 15))
        XCTAssertTrue(RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone9,3", osMajorVersion: 15))
    }

    func testIPhone7OnNewerIOSDoesNotForceLegacyCompositor() {
        XCTAssertFalse(RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone9,1", osMajorVersion: 16))
    }

    func testNewerIPhonesDoNotUseLegacyCompositorOnIOS15() {
        XCTAssertFalse(RenderCompatibilityPolicy.shouldUseLegacyCompositor(machineIdentifier: "iPhone14,2", osMajorVersion: 15))
    }
}
