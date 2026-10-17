import XCTest
@testable import VeilLink

final class VeilAppearanceThemeTests: XCTestCase {
    func testThemeCatalogKeepsOriginalAppleSoftAndInstrumentAuto() {
        XCTAssertEqual(
            VeilAppearanceSelection.switchableCases,
            [.veilOriginal, .appleSoft, .instrumentAuto, .islet]
        )
        XCTAssertEqual(VeilAppearanceSelection.veilOriginal.title, "Veil 原生")
        XCTAssertEqual(VeilAppearanceSelection.appleSoft.title, "Apple Soft")
        XCTAssertEqual(VeilAppearanceSelection.instrumentAuto.title, "拟物仪器")
        XCTAssertEqual(VeilAppearanceSelection.islet.title, "浮屿")
    }

    func testPlainlineRemainsAnExplicitlyGatedExperimentalTheme() {
        XCTAssertTrue(VeilAppearanceSelection.allCases.contains(.plainline))
        XCTAssertTrue(VeilAppearanceSelection.plainline.isExperimental)
        XCTAssertFalse(VeilAppearanceSelection.switchableCases.contains(.plainline))
    }

    func testInstrumentDayAndNightPalettesRemainDistinct() {
        XCTAssertNotEqual(
            String(describing: VeilAppearanceController.instrumentDay.background),
            String(describing: VeilAppearanceController.instrumentNight.background)
        )
    }
}
