import Foundation
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

    @MainActor
    func testForcedInstrumentModeChangesPaletteImmediately() {
        let appearance = VeilAppearanceController.shared
        let originalSelection = appearance.selection
        let originalMode = appearance.colorMode
        defer {
            appearance.selection = originalSelection
            appearance.setColorMode(originalMode)
        }

        appearance.selection = .instrumentAuto
        appearance.setColorMode(.light)
        let lightBackground = String(describing: appearance.palette.background)
        XCTAssertFalse(appearance.isDarkAppearance)

        appearance.setColorMode(.dark)
        let darkBackground = String(describing: appearance.palette.background)
        XCTAssertTrue(appearance.isDarkAppearance)
        XCTAssertNotEqual(lightBackground, darkBackground)
    }

    func testCoreThemeSurfaceRenderersObserveAppearanceChanges() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let token = "@ObservedObject private var appearance = VeilAppearanceController.shared"

        let appTheme = try String(
            contentsOf: repositoryRoot.appendingPathComponent("VeilLink/Core/AppTheme.swift"),
            encoding: .utf8
        )
        let skeuomorphic = try String(
            contentsOf: repositoryRoot.appendingPathComponent("VeilLink/Core/SkeuomorphicComponents.swift"),
            encoding: .utf8
        )
        let motion = try String(
            contentsOf: repositoryRoot.appendingPathComponent("VeilLink/Core/VeilMotionKit.swift"),
            encoding: .utf8
        )
        let appleSoft = try String(
            contentsOf: repositoryRoot.appendingPathComponent("VeilLink/Core/VeilAppleMaterialEngine.swift"),
            encoding: .utf8
        )

        XCTAssertGreaterThanOrEqual(appTheme.components(separatedBy: token).count - 1, 2)
        XCTAssertGreaterThanOrEqual(skeuomorphic.components(separatedBy: token).count - 1, 2)
        XCTAssertGreaterThanOrEqual(motion.components(separatedBy: token).count - 1, 1)
        XCTAssertGreaterThanOrEqual(appleSoft.components(separatedBy: token).count - 1, 4)
    }
}
