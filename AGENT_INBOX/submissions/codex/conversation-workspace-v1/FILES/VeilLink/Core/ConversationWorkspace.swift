import Foundation

enum ConversationWorkspaceKind: String, CaseIterable, Hashable, Sendable {
    case action
    case question
    case link
    case attachment

    var title: String {
        switch self {
        case .action: return "行动项"
        case .question: return "待回答"
        case .link: return "链接"
        case .attachment: return "附件"
        }
    }

    var systemImage: String {
        switch self {
        case .action: return "checklist"
        case .question: return "questionmark.bubble"
        case .link: return "link"
        case .attachment: return "paperclip"
        }
    }
}

struct ConversationWorkspaceItem: Identifiable, Equatable, Sendable {
    let id: String
    let messageID: String
    let kind: ConversationWorkspaceKind
    let title: String
    let preview: String
    let sentAt: Date
    let isOutgoing: Bool
    let value: String?
}

struct ConversationWorkspaceSnapshot: Equatable, Sendable {
    let messageCount: Int
    let outgoingCount: Int
    let incomingCount: Int
    let attachmentCount: Int
    let activeDayCount: Int
    let firstMessageAt: Date?
    let lastMessageAt: Date?
    let items: [ConversationWorkspaceItem]

    func count(for kind: ConversationWorkspaceKind) -> Int {
        items.lazy.filter { $0.kind == kind }.count
    }
}

enum ConversationWorkspaceEngine {
    private static let actionPrefixes = [
        "todo", "to-do", "待办", "记得", "别忘", "请", "需要", "安排", "跟进", "截止", "deadline", "[ ]", "☐"
    ]
    private static let questionPrefixes = [
        "请问", "是否", "怎么", "怎样", "为什么", "为何", "谁", "哪里", "什么时候", "能不能", "可不可以", "可以吗"
    ]
    private static let linkExpression = try? NSRegularExpression(
        pattern: #"https?://[^\s<>\[\]{}\"'，。；：！？、）)]+"#,
        options: [.caseInsensitive]
    )

    static func analyze(_ messages: [ChatMessage], calendar: Calendar = .current) -> ConversationWorkspaceSnapshot {
        let userMessages = messages
            .filter(isUserFacing)
            .sorted { lhs, rhs in
                if lhs.sentAt == rhs.sentAt { return lhs.id < rhs.id }
                return lhs.sentAt < rhs.sentAt
            }
        var items: [ConversationWorkspaceItem] = []
        var activeDays = Set<Date>()
        var attachmentCount = 0

        for message in userMessages {
            activeDays.insert(calendar.startOfDay(for: message.sentAt))
            if let attachment = message.attachment {
                attachmentCount += 1
                let label = attachmentLabel(attachment)
                items.append(ConversationWorkspaceItem(
                    id: "\(message.id):attachment",
                    messageID: message.id,
                    kind: .attachment,
                    title: label,
                    preview: "\(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteCount), countStyle: .file)) · \(message.isOutgoing ? "已发送" : "已接收")",
                    sentAt: message.sentAt,
                    isOutgoing: message.isOutgoing,
                    value: attachment.id
                ))
            }

            guard let text = userFacingText(message), !text.isEmpty else { continue }
            let preview = bounded(text)
            if isAction(text) {
                items.append(ConversationWorkspaceItem(
                    id: "\(message.id):action", messageID: message.id, kind: .action,
                    title: "行动项", preview: preview, sentAt: message.sentAt,
                    isOutgoing: message.isOutgoing, value: nil
                ))
            }
            if isQuestion(text) {
                items.append(ConversationWorkspaceItem(
                    id: "\(message.id):question", messageID: message.id, kind: .question,
                    title: "问题", preview: preview, sentAt: message.sentAt,
                    isOutgoing: message.isOutgoing, value: nil
                ))
            }
            for (index, link) in links(in: text).enumerated() {
                items.append(ConversationWorkspaceItem(
                    id: "\(message.id):link:\(index)", messageID: message.id, kind: .link,
                    title: link, preview: preview, sentAt: message.sentAt,
                    isOutgoing: message.isOutgoing, value: link
                ))
            }
        }

        items.sort {
            if $0.sentAt == $1.sentAt { return $0.id < $1.id }
            return $0.sentAt > $1.sentAt
        }
        return ConversationWorkspaceSnapshot(
            messageCount: userMessages.count,
            outgoingCount: userMessages.lazy.filter(\.isOutgoing).count,
            incomingCount: userMessages.lazy.filter { !$0.isOutgoing }.count,
            attachmentCount: attachmentCount,
            activeDayCount: activeDays.count,
            firstMessageAt: userMessages.first?.sentAt,
            lastMessageAt: userMessages.last?.sentAt,
            items: items
        )
    }

    static func filteredItems(
        in snapshot: ConversationWorkspaceSnapshot,
        kind: ConversationWorkspaceKind?,
        query: String
    ) -> [ConversationWorkspaceItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot.items.filter { item in
            guard kind == nil || item.kind == kind else { return false }
            guard !needle.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(needle)
                || item.preview.localizedCaseInsensitiveContains(needle)
                || item.value?.localizedCaseInsensitiveContains(needle) == true
        }
    }

    private static func isUserFacing(_ message: ChatMessage) -> Bool {
        MiniGameCodec.decode(message.body) == nil && TacticalV2.WireCodecV2.decode(message.body) == nil
    }

    private static func userFacingText(_ message: ChatMessage) -> String? {
        if message.attachment != nil || message.body == "[图片]" || VoiceMessageCodec.decode(message.body) != nil { return nil }
        let raw = ReplyTextCodec.decode(message.body)?.reply ?? message.body
        let normalized = raw
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func isAction(_ text: String) -> Bool {
        let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered.hasPrefix("请问") { return false }
        return actionPrefixes.contains { lowered.hasPrefix($0) }
    }

    private static func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("?") || trimmed.contains("？") { return true }
        return questionPrefixes.contains { trimmed.hasPrefix($0) }
    }

    private static func links(in text: String) -> [String] {
        guard let linkExpression else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return linkExpression.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?，。；：！？、)）"))
        }
    }

    private static func attachmentLabel(_ attachment: ChatAttachment) -> String {
        if VoiceMessageCodec.isVoiceMIMEType(attachment.mimeType) { return "语音消息" }
        if MediaTransferPolicy.supportsImageMIMEType(attachment.mimeType) { return "图片" }
        return "附件"
    }

    private static func bounded(_ text: String, limit: Int = 220) -> String {
        guard text.count > limit else { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<end]) + "…"
    }
}
