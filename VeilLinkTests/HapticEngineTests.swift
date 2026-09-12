import Foundation
import XCTest
@testable import VeilLink

@MainActor
final class HapticEngineTests: XCTestCase {
    func testHapticsDefaultToEnabledAndBalancedForFreshPreferences() {
        let suite = "studio.zeo.veillink.tests.haptics.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let haptics = HapticEngine(defaults: defaults)
        XCTAssertTrue(haptics.isEnabled)
        XCTAssertEqual(haptics.strength, .balanced)
    }

    func testHapticPreferencesPersist() {
        let suite = "studio.zeo.veillink.tests.haptics.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        var haptics: HapticEngine? = HapticEngine(defaults: defaults)
        haptics?.isEnabled = false
        haptics?.strength = .strong
        haptics = nil

        let restored = HapticEngine(defaults: defaults)
        XCTAssertFalse(restored.isEnabled)
        XCTAssertEqual(restored.strength, .strong)
    }
}
