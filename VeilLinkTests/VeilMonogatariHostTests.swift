import XCTest
@testable import VeilLink

final class VeilMonogatariHostTests: XCTestCase {
    func testOfflineMonogatariEngineAssetsPresentInAppBundle() throws {
        let root = try XCTUnwrap(
            VeilMonogatariBundle.resourceRoot(),
            "XcodeGen must bundle MonogatariHost as a folder preserving relative URLs."
        )
        for relative in VeilMonogatariBundle.requiredFiles {
            let url = root.appendingPathComponent(relative)
            XCTAssertTrue(FileManager.default.isReadableFile(atPath: url.path), relative)
        }
        let html = try String(contentsOf: root.appendingPathComponent("index.html"), encoding: .utf8)
        XCTAssertTrue(html.contains("engine/monogatari.js"))
        XCTAssertTrue(html.contains("script.js"))
        XCTAssertTrue(html.contains("connect-src"))
    }

    func testOfflineMonogatariStoryContainsTwoBranchLabels() throws {
        let root = try XCTUnwrap(VeilMonogatariBundle.resourceRoot())
        let script = try String(contentsOf: root.appendingPathComponent("script.js"), encoding: .utf8)
        XCTAssertTrue(script.contains("'Start':"))
        XCTAssertTrue(script.contains("'Station':"))
        XCTAssertTrue(script.contains("'Shelter':"))
        XCTAssertTrue(script.contains("'Choice':"))
    }
}
