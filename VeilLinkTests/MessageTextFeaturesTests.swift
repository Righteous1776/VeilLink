import XCTest
@testable import VeilLink

final class MessageTextFeaturesTests: XCTestCase {
    func testReplyEncodingRoundTrips() {
        let encoded = ReplyTextCodec.encode(quoted: "原来的消息", reply: "这是回复")
        XCTAssertEqual(ReplyTextCodec.decode(encoded), ReplyTextPayload(quote: "原来的消息", reply: "这是回复"))
    }

    func testReplyQuoteNormalizesMultilineAndNestedReply() {
        let original = ChatMessage(
            id: UUID().uuidString,
            conversationID: "c",
            senderIdentityID: "peer",
            body: ReplyTextCodec.encode(quoted: "更早的内容", reply: "第一行\n第二行"),
            sentAt: Date(),
            isOutgoing: false,
            deliveryState: .delivered
        )
        XCTAssertEqual(ReplyTextCodec.quoteSource(for: original), "第一行 第二行")
    }

    func testImageReplyUsesReadableImageLabel() {
        let image = ChatMessage(
            id: UUID().uuidString,
            conversationID: "c",
            senderIdentityID: "peer",
            body: "[图片]",
            sentAt: Date(),
            isOutgoing: false,
            deliveryState: .delivered,
            attachment: ChatAttachment(id: "a", mimeType: "image/jpeg", byteCount: 10)
        )
        XCTAssertEqual(ReplyTextCodec.quoteSource(for: image), "图片")
    }

    func testReplyPreviewShowsOnlyNewReply() {
        let encoded = ReplyTextCodec.encode(quoted: "旧内容", reply: "新的回答")
        XCTAssertEqual(ReplyTextCodec.previewText(for: encoded), "↪︎ 新的回答")
    }

    func testConversationSearchMatchesQuoteAndReply() {
        let message = ChatMessage(
            id: UUID().uuidString,
            conversationID: "c",
            senderIdentityID: "peer",
            body: ReplyTextCodec.encode(quoted: "alpha 原文", reply: "beta 回答"),
            sentAt: Date(),
            isOutgoing: false,
            deliveryState: .delivered
        )
        XCTAssertTrue(ConversationSearch.matches(message, query: "ALPHA"))
        XCTAssertTrue(ConversationSearch.matches(message, query: "beta"))
        XCTAssertFalse(ConversationSearch.matches(message, query: "gamma"))
    }
}
