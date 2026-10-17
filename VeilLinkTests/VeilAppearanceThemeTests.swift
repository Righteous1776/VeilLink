import XCTest
@testable import VeilLink

final class VeilAppearanceThemeTests: XCTestCase {
    func testThemeCatalogKeepsExistingChoicesAndGatesExperimentalStyles() {
        XCTAssertEqual(VeilAppearanceSelection.switchableCases, [.veilOriginal, .appleSoft, .instrumentAuto, .islet])
        XCTAssertEqual(VeilAppearanceSelection.allCases, [.veilOriginal, .appleSoft, .instrumentAuto, .plainline, .islet])
        XCTAssertTrue(VeilAppearanceSelection.plainline.isExperimental)
        XCTAssertFalse(VeilAppearanceSelection.islet.isExperimental)
        XCTAssertEqual(VeilAppearanceSelection.veilOriginal.title, "Veil 原生")
        XCTAssertEqual(VeilAppearanceSelection.appleSoft.title, "Apple Soft")
        XCTAssertEqual(VeilAppearanceSelection.instrumentAuto.title, "拟物仪器")
        XCTAssertEqual(VeilAppearanceSelection.plainline.title, "白描")
        XCTAssertEqual(VeilAppearanceSelection.islet.title, "浮屿")
    }

    func testInstrumentDayAndNightPalettesRemainDistinct() {
        XCTAssertNotEqual(
            String(describing: VeilAppearanceController.instrumentDay.background),
            String(describing: VeilAppearanceController.instrumentNight.background)
        )
    }
}
