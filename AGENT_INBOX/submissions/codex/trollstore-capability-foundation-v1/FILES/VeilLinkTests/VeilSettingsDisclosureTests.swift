import XCTest
@testable import VeilLink

final class VeilSettingsDisclosureTests: XCTestCase {
    func testSectionStorageKeysAreStableAndUnique() {
        let keys = VeilSettingsSection.allCases.map(\.storageKey)
        XCTAssertEqual(Set(keys).count, VeilSettingsSection.allCases.count)
        XCTAssertEqual(VeilSettingsSection.appearanceAndData.storageKey, "settings.section.appearanceAndData.expanded")
        XCTAssertEqual(VeilSettingsSection.connectivity.storageKey, "settings.section.connectivity.expanded")
        XCTAssertEqual(VeilSettingsSection.intelligence.storageKey, "settings.section.intelligence.expanded")
    }

    func testAllSecondaryGroupsDefaultCollapsed() {
        XCTAssertTrue(VeilSettingsSection.allCases.allSatisfy { !$0.defaultExpanded })
    }
}
