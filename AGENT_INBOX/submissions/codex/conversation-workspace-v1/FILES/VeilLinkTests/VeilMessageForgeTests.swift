import XCTest
@testable import VeilLink

final class VeilMessageForgeTests: XCTestCase {
    func testOriginalOnlyNormalizesOuterWhitespaceAndCRLF() {
        XCTAssertEqual(VeilMessageForge.render("  a\r\nb  ", style: .original), "a\nb")
    }

    func testCompactCollapsesWhitespaceWithoutDroppingWords() {
        XCTAssertEqual(VeilMessageForge.render("a   b\n\n\n c", style: .compact), "a b\n\nc")
    }

    func testBulletsSplitLinesAndSentenceTerminators() {
        XCTAssertEqual(VeilMessageForge.render("第一项。第二项\n第三项", style: .bullets), "• 第一项\n• 第二项\n• 第三项")
    }

    func testPoliteRequestDoesNotDuplicateGreetingOrThanks() {
        XCTAssertEqual(VeilMessageForge.render("请处理", style: .politeRequest), "你好，\n请处理\n谢谢。")
        XCTAssertEqual(VeilMessageForge.render("你好，请处理\n谢谢。", style: .politeRequest), "你好，请处理\n谢谢。")
    }

    func testUTF8BudgetUsesBytesNotCharacterCount() {
        let analysis = VeilMessageForge.analyze(String(repeating: "中", count: 6), maximumBytes: 10)
        XCTAssertEqual(analysis.utf8Bytes, 18)
        XCTAssertFalse(analysis.withinSingleMessageLimit)
        XCTAssertEqual(analysis.segments, ["中中中", "中中中"])
    }

    func testSplitNeverBreaksExtendedGraphemeCluster() {
        let family = "👨‍👩‍👧‍👦"
        XCTAssertEqual(VeilMessageForge.split(family + family, maximumBytes: family.utf8.count), [family, family])
    }

    func testPrivateKeyAndTokenAreCriticalWithoutReturningSecret() {
        let text = "-----BEGIN PRIVATE KEY-----\nBearer abcdefghijklmnopqrstuvwxyz"
        let findings = VeilMessageForge.safetyFindings(in: text)
        XCTAssertEqual(Set(findings.map(\.kind)), Set([.privateKey, .accessToken]))
        XCTAssertTrue(findings.allSatisfy { $0.severity == .critical })
        XCTAssertFalse(findings.map(\.guidance).joined().contains("abcdefghijklmnopqrstuvwxyz"))
    }

    func testPasswordEmailAndPhoneWarnings() {
        let findings = VeilMessageForge.safetyFindings(in: "password: secret123 user@example.com +86 138 0013 8000")
        XCTAssertEqual(Set(findings.map(\.kind)), Set([.passwordAssignment, .emailAddress, .phoneNumber]))
    }

    func testEmptyMessageCannotPassSingleMessageLimit() {
        let analysis = VeilMessageForge.analyze("   ")
        XCTAssertFalse(analysis.withinSingleMessageLimit)
        XCTAssertTrue(analysis.segments.isEmpty)
    }

    func testTemplatesStayWithinProtocolBudget() {
        for template in VeilMessageForgeTemplate.allCases {
            XCTAssertFalse(template.text.isEmpty)
            XCTAssertLessThanOrEqual(template.text.utf8.count, VeilMessageForge.maximumMessageBytes)
        }
    }
}
