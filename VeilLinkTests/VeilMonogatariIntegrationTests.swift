import XCTest
@testable import VeilLink

final class VeilMonogatariIntegrationTests: XCTestCase {
    func testBundledRuntimeAndScriptExist() throws {
        let root = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("VisualNovelBundle", isDirectory: true))
        for path in ["index.html", "engine/core/monogatari.js", "engine/core/monogatari.css",
                     "engine/LICENSE", "js/script.js", "js/main.js", "js/veillink-native.js",
                     "js/veillink-ios15-compat.js", "style/main.css", "style/veillink-mobile.css"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path),
                          "Missing game resource: " + path)
        }
    }
    func testSingleRangeAndInvalidRanges() {
        let whole = VeilNovelRangeParser.resolve(nil, fileLength: 100)
        XCTAssertEqual(whole?.first, 0)
        XCTAssertEqual(whole?.last, 99)
        let suffix = VeilNovelRangeParser.resolve("bytes=-10", fileLength: 100)
        XCTAssertEqual(suffix?.first, 90)
        XCTAssertEqual(suffix?.last, 99)
        XCTAssertNil(VeilNovelRangeParser.resolve("bytes=100-", fileLength: 100))
        XCTAssertNil(VeilNovelRangeParser.resolve("bytes=0-1,5-10", fileLength: 100))
    }
}
