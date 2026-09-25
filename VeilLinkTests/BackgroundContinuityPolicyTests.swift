import XCTest
@testable import VeilLink

final class BackgroundContinuityPolicyTests: XCTestCase {
    func testIOS15UsesLegacyBluetoothTier() {
        let profile = VeilBackgroundCapabilityProfile.resolve(
            osMajorVersion: 15,
            liveActivitiesAllowed: false,
            backgroundRefreshAllowed: true
        )
        XCTAssertEqual(profile.tier, .legacyBluetooth)
        XCTAssertFalse(profile.liveActivityEligible)
        XCTAssertTrue(profile.shouldUseShortTransitionWindow)
        XCTAssertTrue(profile.appRefreshEligible)
    }

    func testModernSystemCanUseLiveActivityBluetoothTier() {
        let profile = VeilBackgroundCapabilityProfile.resolve(
            osMajorVersion: 26,
            liveActivitiesAllowed: true,
            backgroundRefreshAllowed: true
        )
        XCTAssertEqual(profile.tier, .liveActivityBluetooth)
        XCTAssertTrue(profile.liveActivityEligible)
    }

    func testBackgroundRefreshDenialDoesNotDisableBluetoothTier() {
        let profile = VeilBackgroundCapabilityProfile.resolve(
            osMajorVersion: 26,
            liveActivitiesAllowed: true,
            backgroundRefreshAllowed: false
        )
        XCTAssertEqual(profile.tier, .liveActivityBluetooth)
        XCTAssertFalse(profile.appRefreshEligible)
    }
}
