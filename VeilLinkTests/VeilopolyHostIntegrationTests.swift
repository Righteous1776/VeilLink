import XCTest
import VeilopolyUI
@testable import VeilLink

/// Runs inside the real VeilLink test host, unlike portable package-only tests.
final class VeilopolyHostIntegrationTests: XCTestCase {
    func testOfflineModuleResourcesTravelWithTheHostApp() {
        XCTAssertEqual(VeilopolyBundledContent.imageAliases.count, 99)
        XCTAssertEqual(VeilopolyBundledContent.sounds.count, 13)
        XCTAssertEqual(VeilopolyBundledContent.missingResources, [])
        XCTAssertEqual(VeilopolyBundledContent.invalidImages, [])
    }

    func testConfirmedTextIsAvailableFromTheLinkedGameModule() {
        let text = VeilopolyBundledContent.compiledTextCounts
        XCTAssertEqual(text["cards"], 32)
        XCTAssertEqual(text["streets"], 40)
        XCTAssertEqual(text["issuers"], 5)
        XCTAssertEqual(text["guide"], 23)
        XCTAssertEqual(text["news"], 86)
    }
}
