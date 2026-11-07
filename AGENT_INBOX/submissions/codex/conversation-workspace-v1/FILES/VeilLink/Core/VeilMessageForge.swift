import Foundation

enum VeilMessageForgeStyle: String, CaseIterable, Identifiable, Hashable, Sendable {
    case original
    case compact
    case bullets
    case politeRequest

    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "原文"
        case .compact: return "紧凑"
        case .bullets: return "要点"
        case .politeRequest: return "礼貌请求"
        }
    }
}

enum VeilMessageForgeTemplate: String, CaseIterable, Identifiable, Sendable {
    case status
    case request
    case meeting
    case checklist
    case incident

    var id: String { rawValue }
    var title: String {
        switch self {
        case .status: return "进展同步"
        case .request: return "明确请求"
        case .meeting: return "会议约定"
        case .checklist: return "待办清单"
        case .incident: return "问题报告"
        }
    }

    var text: String {
        switch self {
        case .status: return "进展：\n- 已完成：\n- 进行中：\n- 下一步：\n- 阻塞："
        case .request: return "你好，我需要你协助：\n\n目标：\n期望结果：\n截止时间：\n补充信息：\n\n谢谢。"
        case .meeting: return "主题：\n建议时间：\n预计时长：\n需要准备：\n确认方式："
        case .checklist: return "待办：\n☐ \n☐ \n☐ "
        case .incident: return "问题：\n影响：\n复现步骤：\n1. \n2. \n当前状态：\n需要协助："
        }
    }
}

enum VeilMessageSafetySeverity: Int, Comparable, Sendable {
    case notice = 0
    case warning = 1
    case critical = 2
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct VeilMessageSafetyFinding: Identifiable, Equatable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case privateKey
        case accessToken
        case passwordAssignment
        case emailAddress
        case phoneNumber
    }

    var id: String { kind.rawValue }
    let kind: Kind
    let severity: VeilMessageSafetySeverity
    let title: String
    let guidance: String
}

struct VeilMessageForgeAnalysis: Equatable, Sendable {
    let characters: Int
    let utf8Bytes: Int
    let lines: Int
    let segments: [String]
    let findings: [VeilMessageSafetyFinding]
    let withinSingleMessageLimit: Bool
}

enum VeilMessageForge {
    static let maximumMessageBytes = 16_384

    static func render(_ source: String, style: VeilMessageForgeStyle) -> String {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }
        switch style {
        case .original:
            return normalized
        case .compact:
            return normalized
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
                .reduce(into: [String]()) { lines, line in
                    if !line.isEmpty || lines.last?.isEmpty == false { lines.append(line) }
                }
                .joined(separator: "\n")
        case .bullets:
            let lines = normalized.split(separator: "\n").flatMap { line in
                line.split(whereSeparator: { ".。;；".contains($0) })
            }
            return lines.map { "• " + $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0 != "• " }.joined(separator: "\n")
        case .politeRequest:
            let hasGreeting = normalized.hasPrefix("你好") || normalized.hasPrefix("您好")
            let hasThanks = normalized.hasSuffix("谢谢") || normalized.hasSuffix("谢谢。")
            return (hasGreeting ? "" : "你好，\n") + normalized + (hasThanks ? "" : "\n谢谢。")
        }
    }

    static func analyze(_ text: String, maximumBytes: Int = maximumMessageBytes) -> VeilMessageForgeAnalysis {
        let segments = split(text, maximumBytes: maximumBytes)
        return VeilMessageForgeAnalysis(
            characters: text.count,
            utf8Bytes: text.utf8.count,
            lines: text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count,
            segments: segments,
            findings: safetyFindings(in: text),
            withinSingleMessageLimit: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && text.utf8.count <= maximumBytes
        )
    }

    static func split(_ text: String, maximumBytes: Int = maximumMessageBytes) -> [String] {
        guard maximumBytes > 0 else { return [] }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        var segments: [String] = []
        var current = ""

        func flush() {
            let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { segments.append(value) }
            current = ""
        }

        for character in normalized {
            let candidate = current + String(character)
            if candidate.utf8.count > maximumBytes {
                flush()
                current = String(character)
                if current.utf8.count > maximumBytes { flush() }
            } else {
                current = candidate
            }
        }
        flush()
        return segments
    }

    static func safetyFindings(in text: String) -> [VeilMessageSafetyFinding] {
        let patterns: [(VeilMessageSafetyFinding.Kind, VeilMessageSafetySeverity, String, String, String)] = [
            (.privateKey, .critical, #"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\b(?:seed phrase|助记词)\b"#, "可能包含私钥或助记词", "不要通过聊天发送密钥材料；请删除后再发送。"),
            (.accessToken, .critical, #"\b(?:Bearer\s+[A-Za-z0-9._~+/=-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"#, "可能包含访问令牌", "撤销已暴露令牌，并从消息中移除。"),
            (.passwordAssignment, .warning, #"(?i)\b(?:password|passwd|pwd|密码)\s*[:=：]\s*\S{4,}"#, "可能包含密码", "确认对方和场景可信；建议改用专门的秘密传递方式。"),
            (.emailAddress, .notice, #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, "包含邮箱地址", "发送前确认是否需要暴露个人联系方式。"),
            (.phoneNumber, .notice, #"(?<!\d)(?:\+?\d[\d -]{8,}\d)(?!\d)"#, "可能包含电话号码", "发送前确认是否需要暴露个人联系方式。")
        ]
        return patterns.compactMap { kind, severity, pattern, title, guidance in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil else { return nil }
            return VeilMessageSafetyFinding(kind: kind, severity: severity, title: title, guidance: guidance)
        }
        .sorted { $0.severity > $1.severity }
    }
}
