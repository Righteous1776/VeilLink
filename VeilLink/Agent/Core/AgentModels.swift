import Foundation

enum AgentRuntimeState: String, Codable, CaseIterable, Sendable {
    case unloaded
    case loading
    case ready
    case generating
    case cooling
    case unavailable

    var displayName: String {
        switch self {
        case .unloaded: return "未载入"
        case .loading: return "载入中"
        case .ready: return "本地就绪"
        case .generating: return "生成中"
        case .cooling: return "受限"
        case .unavailable: return "不可用"
        }
    }
}

enum AgentMessageRole: String, Codable, Sendable {
    case user
    case assistant
}

struct AgentMessage: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let role: AgentMessageRole
    var text: String
    let createdAt: Date

    init(id: String = UUID().uuidString, role: AgentMessageRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct AgentTextRequest: Equatable, Sendable {
    let sessionID: String
    let messages: [AgentMessage]
    let userText: String
    let maxNewTokens: Int
    let visualContext: AgentVisualContext?
}

struct AgentTextResult: Equatable, Sendable {
    let text: String
    let emittedChunkCount: Int
    let estimatedTokenCount: Int
}

enum AgentRuntimeError: LocalizedError, Equatable {
    case cancelled
    case unavailable(String)
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .cancelled: return "本地生成已停止。"
        case .unavailable(let reason): return reason
        case .invalidRequest: return "没有可生成的本地输入。"
        }
    }
}
