import Foundation

enum AgentToolCommand: Equatable, Sendable {
    case refreshBLE
    case databaseIntegrity
    case a9Status
    case agentStatus
    case gameStatus
    case executeSuggestedGameMove
}

struct AgentToolExecution: Equatable, Sendable {
    let command: String
    let message: String
}

enum AgentToolRouter {
    static func parse(_ raw: String) -> AgentToolCommand? {
        let text = normalized(raw)
        switch text {
        case "/ble refresh", "刷新蓝牙", "刷新蓝牙链路", "刷新链路":
            return .refreshBLE
        case "/db check", "检查数据库", "检查数据库完整性", "数据库完整性检查":
            return .databaseIntegrity
        case "/a9 status", "a9状态", "查看a9状态", "查看 A9 状态":
            return .a9Status
        case "/agent status", "灵核状态", "查看灵核状态":
            return .agentStatus
        case "/game status", "当前对局状态", "查看当前对局":
            return .gameStatus
        case "/game move", "执行建议着法", "执行推荐着法", "走推荐的一步":
            return .executeSuggestedGameMove
        default:
            return nil
        }
    }

    static let advertisedCommands = [
        "/ble refresh",
        "/db check",
        "/a9 status",
        "/agent status",
        "/game status",
        "/game move"
    ]

    private static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "　", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .lowercased()
    }
}
