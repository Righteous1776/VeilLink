import Foundation
import XCTest
@testable import VeilLink

final class VeilHTMLImportPolicyTests: XCTestCase {
    func testUTF8AndChinese() throws {
        let html = "<h1>离线资料</h1><p>您好！</p>"
        XCTAssertEqual(try VeilHTMLImportPolicy.decode(Data(html.utf8)), html)
        XCTAssertEqual(try VeilHTMLImportPolicy.decode(Data([0xEF,0xBB,0xBF]) + Data(html.utf8)), html)
    }
    func testUTF16BOM() throws {
        let text = "<html>测试</html>"
        let raw = Data([0xFF,0xFE]) + (text.data(using: .utf16LittleEndian) ?? Data())
        XCTAssertEqual(try VeilHTMLImportPolicy.decode(raw), text)
    }
    func testRejectsEmptyAndOversized() throws {
        XCTAssertThrowsError(try VeilHTMLImportPolicy.decode(Data()))
        XCTAssertThrowsError(try VeilHTMLImportPolicy.decode(Data(repeating: 65, count: 512*1024+1)))
        XCTAssertEqual(try VeilHTMLImportPolicy.decode(Data(repeating: 65, count: 512*1024)).count, 512*1024)
    }
    func testRejectsMalformedUTF8() throws {
        XCTAssertThrowsError(try VeilHTMLImportPolicy.decode(Data([0xFF,0xFF,0xC0])))
    }
    func testSafeLinksRejectActiveSchemes() {
        XCTAssertEqual(VeilHTMLImportPolicy.safeExternalLink("https://example.org/post?q=你好"), "https://example.org/post?q=你好")
        for url in ["javascript:alert(1)", "file:///tmp/private", "data:text/html,a",
                    "https://user:pw@example.org", "https://example.org\nnext", "https://"] {
            XCTAssertNil(VeilHTMLImportPolicy.safeExternalLink(url), url)
        }
        XCTAssertNil(VeilHTMLImportPolicy.safeExternalLink(String(repeating: "a", count: 3000)))
    }
    func testBoundedAndSearch() {
        XCTAssertEqual(VeilHTMLImportPolicy.bounded("ABCDE", limit: 3), "ABC")
        XCTAssertTrue(VeilHTMLImportPolicy.isMatch("SwiftSoup 离线文档", query: " swiftsoup "))
        XCTAssertFalse(VeilHTMLImportPolicy.isMatch("本地安全", query: "网络"))
    }
    func testResultCap() {
        let doc = VeilOfflineHTMLDocument(title: "T", sections: (0..<300).map { "会话 \($0)" }, links: [], truncated: false)
        XCTAssertEqual(doc.matchingSections(query: "会话").count, 100)
    }
}