import XCTest
@testable import VeilLink

final class GlobalAppearanceModeTests: XCTestCase {
    func testAllAppearanceModesExist() {
        XCTAssertEqual(Set(VeilColorMode.allCases.map(\.rawValue)), Set(["automatic", "light", "dark"]))
    }

    func testLightAndDarkResolutionAreDeterministic() {
        XCTAssertFalse(VeilColorMode.light.resolvesDark(systemIsDark: true))
        XCTAssertFalse(VeilColorMode.light.resolvesDark(systemIsDark: false))
        XCTAssertTrue(VeilColorMode.dark.resolvesDark(systemIsDark: true))
        XCTAssertTrue(VeilColorMode.dark.resolvesDark(systemIsDark: false))
    }

    func testAutomaticFollowsSystem() {
        XCTAssertTrue(VeilColorMode.automatic.resolvesDark(systemIsDark: true))
        XCTAssertFalse(VeilColorMode.automatic.resolvesDark(systemIsDark: false))
    }

    func testEverySkinRemainsSelectable() {
        XCTAssertTrue(VeilAppearanceSelection.allCases.contains(.veilOriginal))
        XCTAssertTrue(VeilAppearanceSelection.allCases.contains(.appleSoft))
        XCTAssertTrue(VeilAppearanceSelection.allCases.contains(.instrumentAuto))
    }
}
