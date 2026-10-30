import Foundation
import XCTest
@testable import VeilLink

/// Requires SwiftSoup 2.9.6 on the approved iOS integration branch.
final class VeilOfflineHTMLImporterTests: XCTestCase {
    func testExtractsChineseArticleAndInertLinks() throws {
        let html = """
        <html><head><title>离线阅读</title><script>danger()</script></head>
        <body><nav>跳过导航</nav><h1>第一章</h1><p>你好 &amp; 世界。</p>
        <a href="https://example.org/a">资料链接</a>
        <a href="javascript:alert(1)">脚本链接</a></body></html>
        """
        let doc = try VeilOfflineHTMLImporter.parse(Data(html.utf8))
        XCTAssertEqual(doc.title, "离线阅读")
        XCTAssertTrue(doc.sections.contains("第一章"))
        XCTAssertTrue(doc.sections.contains("你好 & 世界。"))
        XCTAssertFalse(doc.sections.joined().contains("danger"))
        XCTAssertFalse(doc.sections.joined().contains("跳过导航"))
        XCTAssertEqual(doc.links.map(\.address), ["https://example.org/a"])
    }

    func testDeduplicatesLinksAndSkipsFrames() throws {
        let source = """
        <title>测试</title><body><p>正文</p>
        <a href="https://example.com">一</a><a href="https://example.com">二</a>
        <iframe src="https://example.com"></iframe><style>bad</style></body>
        """
        let doc = try VeilOfflineHTMLImporter.parse(Data(source.utf8))
        XCTAssertEqual(doc.links.count, 1)
        XCTAssertTrue(doc.sections.contains("正文"))
    }

    func testFallbackForPlainBody() throws {
        let doc = try VeilOfflineHTMLImporter.parse(Data("<body>Plain content 中文</body>".utf8))
        XCTAssertEqual(doc.sections, ["Plain content 中文"])
    }

    func testEmptyBodyAndOversizeRejected() throws {
        XCTAssertThrowsError(try VeilOfflineHTMLImporter.parse(Data("<body><script>evil()</script></body>".utf8)))
        XCTAssertThrowsError(try VeilOfflineHTMLImporter.parse(Data(repeating: 65, count: VeilHTMLImportPolicy.maximumSourceBytes + 1)))
    }
}
