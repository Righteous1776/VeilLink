import Foundation

struct ReplyTextPayload: Equatable {
    let quote: String
    let reply: String
}

enum ReplyTextCodec {
    private static let prefix = "↪︎「"
    private static let separator = "」\n"
    static let maximumQuoteCharacters = 160

    static func quoteSource(for message: ChatMessage) -> String {
        if message.attachment != nil || message.body == "[图片]" { return "图片" }
        let source = decode(message.body)?.reply ?? message.body
        return normalizedQuote(source)
    }

    static func encode(quoted: String, reply: String) -> String {
        let cleanReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix + normalizedQuote(quoted) + separator + cleanReply
    }

    static func decode(_ body: String) -> ReplyTextPayload? {
        guard body.hasPrefix(prefix),
              let separatorRange = body.range(of: separator, range: body.index(body.startIndex, offsetBy: prefix.count)..<body.endIndex) else {
            return nil
        }
        let quoteStart = body.index(body.startIndex, offsetBy: prefix.count)
        let quote = String(body[quoteStart..<separatorRange.lowerBound])
        let reply = String(body[separatorRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty, !reply.isEmpty else { return nil }
        return ReplyTextPayload(quote: quote, reply: reply)
    }

    static func previewText(for body: String) -> String {
        guard let payload = decode(body) else { return body }
        return "↪︎ " + payload.reply
    }

    private static func normalizedQuote(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard collapsed.count > maximumQuoteCharacters else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: maximumQuoteCharacters)
        return String(collapsed[..<end]) + "…"
    }
}

enum ConversationSearch {
    static func matches(_ message: ChatMessage, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        if message.body.localizedCaseInsensitiveContains(needle) { return true }
        if let payload = ReplyTextCodec.decode(message.body) {
            return payload.quote.localizedCaseInsensitiveContains(needle)
                || payload.reply.localizedCaseInsensitiveContains(needle)
        }
        return false
    }
}
