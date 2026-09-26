import XCTest
@testable import VeilLink

final class AppleSoftThemeTests: XCTestCase {
    func testAppleSoftThemeIsSelectable() {
        XCTAssertTrue(VeilAppearanceSelection.allCases.contains(.appleSoft))
        XCTAssertFalse(VeilAppearanceSelection.appleSoft.title.isEmpty)
    }

    func testLiquidGlassDiagnosticAlwaysResolves() {
        XCTAssertFalse(VeilPlatformMaterialEngine.diagnosticLabel.isEmpty)
    }

    func testThemeSelectionRoundTripsRawValue() {
        XCTAssertEqual(VeilAppearanceSelection(rawValue: "appleSoft"), .appleSoft)
    }
}
