import XCTest
@testable import VeilLink

final class VeilAppearanceThemeTests: XCTestCase {
    func testThemeCatalogKeepsOriginalAndInstrumentAuto() {
        XCTAssertEqual(VeilAppearanceSelection.allCases, [.veilOriginal, .instrumentAuto])
        XCTAssertEqual(VeilAppearanceSelection.veilOriginal.title, "Veil 原生")
        XCTAssertEqual(VeilAppearanceSelection.instrumentAuto.title, "仪器 · 自动")
    }

    func testInstrumentDayAndNightPalettesRemainDistinct() {
        XCTAssertNotEqual(
            String(describing: VeilAppearanceController.instrumentDay.background),
            String(describing: VeilAppearanceController.instrumentNight.background)
        )
    }
}
