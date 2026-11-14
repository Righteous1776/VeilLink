import XCTest
@testable import VeilLink

final class VeilForgeMotionCoreTests: XCTestCase {
    func testStepperDetentsAndPhaseRepeat() {
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: 0, working: true), 0)
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: 0.09, working: true), 7.5)
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: 0.18, working: true), 15)
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: 4.09, working: true), 7.5)
    }

    func testParkedMotorAndBadInputsNeverAdvance() {
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: 3.7, working: false), 0)
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: -.infinity, working: true), 0)
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: .nan, working: true), 0)
        XCTAssertEqual(VeilForgeMotionCore.rotorAngle(atSeconds: -25, working: true), 0)
    }

    func testHealthBarsClampActualBLEHealthScore() {
        XCTAssertEqual(VeilForgeMotionCore.healthBars(-1), 0)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(0), 0)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(1), 1)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(25), 2)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(50), 4)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(75), 6)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(100), 8)
        XCTAssertEqual(VeilForgeMotionCore.healthBars(101), 8)
    }
    func testRoutingCarriageStatesComeFromRealPeerCounts() {
        XCTAssertEqual(VeilForgeMotionCore.routeStage(connectedPeers: 0, securePeers: 0), 0)
        XCTAssertEqual(VeilForgeMotionCore.routeStage(connectedPeers: 2, securePeers: 0), 1)
        XCTAssertEqual(VeilForgeMotionCore.routeStage(connectedPeers: 4, securePeers: 2), 2)
        XCTAssertEqual(VeilForgeMotionCore.routeStage(connectedPeers: 0, securePeers: 1), 2)
        XCTAssertEqual(VeilForgeMotionCore.routeStage(connectedPeers: -1, securePeers: -9), 0)
    }

    func testForgeThemeCaseIsAvailableWithoutReplacingLegacyThemes() {
        XCTAssertTrue(VeilAppearanceSelection.switchableCases.contains(.forge))
        XCTAssertEqual(VeilAppearanceSelection.forge.rawValue, "forge")
        XCTAssertEqual(VeilAppearanceSelection(rawValue: "forge"), .forge)
        XCTAssertEqual(VeilAppearanceSelection.forge.title, "FORGE · 锻造")
        XCTAssertEqual(VeilAppearanceSelection.switchableCases.count, 5)
        XCTAssertTrue(VeilAppearanceSelection.switchableCases.contains(.instrumentAuto))
        XCTAssertTrue(VeilAppearanceSelection.switchableCases.contains(.veilOriginal))
    }

}
