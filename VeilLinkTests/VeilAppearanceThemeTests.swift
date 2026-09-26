import XCTest
@testable import VeilLink

final class VeilAppearanceThemeTests: XCTestCase {
    func testThemeCatalogKeepsOriginalAppleSoftAndInstrumentAuto() {
        XCTAssertEqual(VeilAppearanceSelection.allCases, [.veilOriginal, .appleSoft, .instrumentAuto])
        XCTAssertEqual(VeilAppearanceSelection.veilOriginal.title, "Veil 原生")
        XCTAssertEqual(VeilAppearanceSelection.appleSoft.title, "Apple Soft")
        XCTAssertEqual(VeilAppearanceSelection.instrumentAuto.title, "拟物仪器")
    }

    func testInstrumentDayAndNightPalettesRemainDistinct() {
        XCTAssertNotEqual(
            String(describing: VeilAppearanceController.instrumentDay.background),
            String(describing: VeilAppearanceController.instrumentNight.background)
        )
    }
}
