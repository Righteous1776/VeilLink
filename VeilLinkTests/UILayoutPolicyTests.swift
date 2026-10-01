import XCTest
@testable import VeilLink

final class UILayoutPolicyTests: XCTestCase {
    func testRegularButNarrowViewportFallsBackToPhone() {
        XCTAssertFalse(VeilUILayoutPolicy.usesTabletTwoPane(horizontalSizeClassRegular: true, viewportWidth: 650))
        XCTAssertTrue(VeilUILayoutPolicy.usesTabletTwoPane(horizontalSizeClassRegular: true, viewportWidth: 834))
        XCTAssertFalse(VeilUILayoutPolicy.usesTabletTwoPane(horizontalSizeClassRegular: false, viewportWidth: 900))
    }

    func testTabletSidebarRemainsBounded() {
        XCTAssertEqual(VeilUILayoutPolicy.sidebarWidth(viewportWidth: 1_200), 330, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(VeilUILayoutPolicy.sidebarWidth(viewportWidth: 720), 250)
        XCTAssertLessThanOrEqual(VeilUILayoutPolicy.sidebarWidth(viewportWidth: 720), 330)
    }

    func testLandscapeLockUsesCompactKeypad() {
        let landscape = CGSize(width: 844, height: 390)
        let portrait = CGSize(width: 390, height: 844)
        XCTAssertTrue(VeilUILayoutPolicy.lockUsesHorizontalLayout(size: landscape))
        XCTAssertFalse(VeilUILayoutPolicy.lockUsesHorizontalLayout(size: portrait))
        XCTAssertEqual(VeilUILayoutPolicy.lockKeySize(size: landscape), 50, accuracy: 0.001)
        XCTAssertEqual(VeilUILayoutPolicy.lockKeySize(size: portrait), 68, accuracy: 0.001)
    }
}
