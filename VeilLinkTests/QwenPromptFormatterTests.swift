import XCTest
@testable import VeilLink

final class QwenPromptFormatterTests: XCTestCase {
    func testPromptUsesChatMLAndNoThink() {
        let request = AgentTextRequest(
            sessionID: "test",
            messages: [AgentMessage(role: .user, text: "你好")],
            userText: "你好",
            maxNewTokens: 16,
            visualContext: nil
        )
        let prompt = QwenPromptFormatter.prompt(request: request, historyLimit: 8)
        XCTAssertTrue(prompt.contains("<|im_start|>system"))
        XCTAssertTrue(prompt.contains("<|im_start|>user"))
        XCTAssertTrue(prompt.contains("/no_think"))
        XCTAssertTrue(prompt.hasSuffix("<|im_start|>assistant\n"))
    }

    func testStructuredMessagesKeepNoThinkOnLatestUser() {
        let request = AgentTextRequest(
            sessionID: "test",
            messages: [
                AgentMessage(role: .user, text: "first"),
                AgentMessage(role: .assistant, text: "reply"),
                AgentMessage(role: .user, text: "latest")
            ],
            userText: "latest",
            maxNewTokens: 16,
            visualContext: nil
        )
        let messages = QwenPromptFormatter.messages(request: request, historyLimit: 8)
        XCTAssertEqual(messages.first?.role, "system")
        XCTAssertEqual(messages.last?.role, "user")
        XCTAssertTrue(messages.last?.content.contains("/no_think") == true)
    }

    func testThinkingFilterHidesSplitReasoningTags() {
        var filter = QwenVisibleOutputFilter()
        XCTAssertEqual(filter.consume("<thi"), "")
        XCTAssertEqual(filter.consume("nk>secret"), "")
        XCTAssertEqual(filter.consume("</thi"), "")
        XCTAssertEqual(filter.consume("nk>answer"), "answer")
        XCTAssertEqual(filter.finish(), "")
    }
}
