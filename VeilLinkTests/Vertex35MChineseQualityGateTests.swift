import XCTest
@testable import VeilLink

final class Vertex35MChineseQualityGateTests: XCTestCase {
    func testChineseInputEnglishOutputFlagged() {
        XCTAssertTrue(Vertex35MChineseQualityGate.needsLanguageWarning(
            userText: "你好，请用中文回答。", modelOutput: "I only speak English."
        ))
    }

    func testChineseResponseAccepted() {
        XCTAssertFalse(Vertex35MChineseQualityGate.needsLanguageWarning(
            userText: "你是谁？", modelOutput: "我是离线聊天助手。"
        ))
    }

    func testEnglishAndEmojiIgnored() {
        XCTAssertFalse(Vertex35MChineseQualityGate.needsLanguageWarning(
            userText: "Hi 👋", modelOutput: "Hello!"
        ))
    }
}
