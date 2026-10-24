import XCTest
@testable import VeilLink

final class ConversationWorkspaceTests: XCTestCase {
    private func message(
        _ body: String,
        id: String = UUID().uuidString,
        date: Date = Date(),
        outgoing: Bool = false,
        attachment: ChatAttachment? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: id, conversationID: "c", senderIdentityID: outgoing ? "local" : "peer",
            body: body, sentAt: date, isOutgoing: outgoing, deliveryState: .delivered,
            attachment: attachment
        )
    }

    func testSummaryCountsDirectionDaysAndAttachments() {
        let day: TimeInterval = 24 * 60 * 60
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let image = ChatAttachment(id: "a", mimeType: "image/jpeg", byteCount: 2_048)
        let snapshot = ConversationWorkspaceEngine.analyze([
            message("你好", date: base),
            message("[图片]", date: base.addingTimeInterval(day), outgoing: true, attachment: image)
        ], calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(snapshot.messageCount, 2)
        XCTAssertEqual(snapshot.incomingCount, 1)
        XCTAssertEqual(snapshot.outgoingCount, 1)
        XCTAssertEqual(snapshot.activeDayCount, 2)
        XCTAssertEqual(snapshot.attachmentCount, 1)
    }

    func testChineseAndEnglishActionPrefixesAreDetected() {
        let snapshot = ConversationWorkspaceEngine.analyze([
            message("待办：更新测试包", id: "a"),
            message("TODO verify iPhone 7", id: "b"),
            message("只是普通聊天", id: "c")
        ])
        XCTAssertEqual(snapshot.count(for: .action), 2)
    }

    func testQuestionsUsePunctuationAndNaturalPrefixes() {
        let snapshot = ConversationWorkspaceEngine.analyze([
            message("明天几点开始？", id: "a"),
            message("怎么恢复连接", id: "b"),
            message("请问现在可以测试吗", id: "d"),
            message("明天开始", id: "c")
        ])
        XCTAssertEqual(snapshot.count(for: .question), 3)
        XCTAssertEqual(snapshot.count(for: .action), 0)
    }

    func testLinksAreExtractedAndTrailingPunctuationRemoved() {
        let snapshot = ConversationWorkspaceEngine.analyze([
            message("资料 https://example.com/a?q=1，以及 http://localhost/test。")
        ])
        let links = snapshot.items.filter { $0.kind == .link }.compactMap(\.value)
        XCTAssertEqual(links, ["https://example.com/a?q=1", "http://localhost/test"])
    }

    func testReplyAnalyzesNewReplyNotQuotedText() {
        let body = ReplyTextCodec.encode(quoted: "待办：旧任务", reply: "这是普通答复")
        XCTAssertEqual(ConversationWorkspaceEngine.analyze([message(body)]).count(for: .action), 0)
    }

    func testVoiceAndImageBecomeReadableAttachmentItems() {
        let voice = ChatAttachment(id: "v", mimeType: "audio/mp4", byteCount: 100)
        let image = ChatAttachment(id: "i", mimeType: "image/png", byteCount: 200)
        let snapshot = ConversationWorkspaceEngine.analyze([
            message(VoiceMessageCodec.encode(durationSeconds: 2), id: "v", attachment: voice),
            message("[图片]", id: "i", attachment: image)
        ])
        XCTAssertEqual(Set(snapshot.items.filter { $0.kind == .attachment }.map(\.title)), Set(["语音消息", "图片"]))
    }

    func testGameProtocolPacketsAreExcluded() throws {
        let packet = MiniGamePacket(game: .gomoku, command: .invite)
        let encoded = try MiniGameCodec.encode(packet)
        let snapshot = ConversationWorkspaceEngine.analyze([message(encoded)])
        XCTAssertEqual(snapshot.messageCount, 0)
        XCTAssertTrue(snapshot.items.isEmpty)
    }

    func testItemsAreNewestFirstWithStableTieBreak() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ConversationWorkspaceEngine.analyze([
            message("待办 A", id: "b", date: date),
            message("待办 B", id: "a", date: date.addingTimeInterval(1))
        ])
        XCTAssertEqual(snapshot.items.map(\.messageID), ["a", "b"])
    }

    func testFilteringCombinesKindAndQuery() {
        let snapshot = ConversationWorkspaceEngine.analyze([
            message("待办：发布测试", id: "a"),
            message("测试地址 https://example.com", id: "b")
        ])
        let result = ConversationWorkspaceEngine.filteredItems(in: snapshot, kind: .action, query: "发布")
        XCTAssertEqual(result.map(\.messageID), ["a"])
    }
}
