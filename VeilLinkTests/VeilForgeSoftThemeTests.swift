import XCTest
@testable import VeilLink

final class VeilForgeSoftThemeTests: XCTestCase {
    func testSoftCardGeometryAndThemeIdentity() {
        XCTAssertEqual(VeilAppearanceSelection.forge.rawValue, "forge")
        XCTAssertEqual(VeilAppearanceSelection.forge.title, "FORGE · 锻造")
        XCTAssertGreaterThanOrEqual(VeilForgeSoftDesign.cardCornerRadius, 18)
        XCTAssertGreaterThan(VeilForgeSoftDesign.emphasizedCornerRadius,
                             VeilForgeSoftDesign.cardCornerRadius)
        XCTAssertGreaterThan(VeilForgeSoftDesign.previewCornerRadius, 10)
        XCTAssertTrue(VeilAppearanceSelection.switchableCases.contains(.forge))
    }

    func testVisualOnlyChangeDoesNotReplaceStateDrivenInstruments() {
        XCTAssertEqual(VeilForgeMotionCore.routeStage(connectedPeers: 0, securePeers: 0), 0)
        XCTAssertEqual(VeilForgeMotionCore.routeStage(connectedPeers: 2, securePeers: 1), 2)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(50), 4)
    }
}
