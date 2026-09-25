import Foundation

enum VeilAppDestination: String, Codable, CaseIterable, Sendable {
    case chats
    case nearby
    case games
    case agent
    case settings

    var title: String {
        switch self {
        case .chats: return "对话"
        case .nearby: return "附近"
        case .games: return "游戏"
        case .agent: return "灵核"
        case .settings: return "设置"
        }
    }
}

enum VeilAppResourceFocus: String, Codable, CaseIterable, Sendable {
    case automatic
    case communications
    case agent
    case game

    var title: String {
        switch self {
        case .automatic: return "自动平衡"
        case .communications: return "通信优先"
        case .agent: return "灵核优先"
        case .game: return "游戏优先"
        }
    }
}

enum VeilAutoRegulationMode: String, Codable, CaseIterable, Sendable {
    case off
    case advisory
    case safeAutomatic

    var title: String {
        switch self {
        case .off: return "关闭"
        case .advisory: return "仅建议"
        case .safeAutomatic: return "安全自动"
        }
    }
}

enum VeilAppControlSource: String, Sendable {
    case agentRequest
    case directUser
    case automaticRegulator
}

enum VeilAppControlCommand: Equatable, Sendable {
    case controlHelp
    case overviewStatus
    case transportStatus
    case mediaStatus
    case performanceStatus
    case diagnosticsStatus
    case autoRegulationStatus
    case refreshBLE
    case startBLE
    case stopBLE
    case databaseIntegrity
    case a9Status
    case agentStatus
    case gameStatus
    case executeSuggestedGameMove
    case trimCaches
    case restoreAutomaticPerformance
    case activateAgentRuntime
    case unloadAgentRuntime
    case setVisualContext(Bool)
    case setAutoSaveReceivedImages(Bool)
    case setResourceFocus(VeilAppResourceFocus)
    case setAutoRegulationMode(VeilAutoRegulationMode)
    case runAutoRegulationOnce
    case exportDiagnostics
    case navigate(VeilAppDestination)

    var id: String {
        switch self {
        case .controlHelp: return "control.help"
        case .overviewStatus: return "app.status"
        case .transportStatus: return "transport.status"
        case .mediaStatus: return "media.status"
        case .performanceStatus: return "performance.status"
        case .diagnosticsStatus: return "diagnostics.status"
        case .autoRegulationStatus: return "autotune.status"
        case .refreshBLE: return "ble.refresh"
        case .startBLE: return "ble.start"
        case .stopBLE: return "ble.stop"
        case .databaseIntegrity: return "db.integrity"
        case .a9Status: return "a9.status"
        case .agentStatus: return "agent.status"
        case .gameStatus: return "game.status"
        case .executeSuggestedGameMove: return "game.execute-suggested"
        case .trimCaches: return "runtime.trim-caches"
        case .restoreAutomaticPerformance: return "performance.automatic"
        case .activateAgentRuntime: return "agent.activate"
        case .unloadAgentRuntime: return "agent.unload"
        case .setVisualContext(let enabled): return enabled ? "agent.visual.enable" : "agent.visual.disable"
        case .setAutoSaveReceivedImages(let enabled): return enabled ? "media.auto-save.enable" : "media.auto-save.disable"
        case .setResourceFocus(let focus): return "scheduler.focus.\(focus.rawValue)"
        case .setAutoRegulationMode(let mode): return "autotune.mode.\(mode.rawValue)"
        case .runAutoRegulationOnce: return "autotune.run-once"
        case .exportDiagnostics: return "diagnostics.export"
        case .navigate(let destination): return "navigation.\(destination.rawValue)"
        }
    }
}

enum VeilAppControlAccess: String, Sendable {
    case readOnly
    case navigation
    case localMutation
    case localExport
    case gameMutation
}

struct VeilAppControlPermissions: Equatable, Sendable {
    let localMutationsEnabled: Bool
    let diagnosticsExportEnabled: Bool
    let suggestedMoveExecutionEnabled: Bool
    let autoRegulationMode: VeilAutoRegulationMode
}

struct VeilAppControlDecision: Equatable, Sendable {
    let allowed: Bool
    let access: VeilAppControlAccess
    let reason: String?
}

enum VeilAppControlPolicy {
    nonisolated static func access(for command: VeilAppControlCommand) -> VeilAppControlAccess {
        switch command {
        case .controlHelp, .overviewStatus, .transportStatus, .mediaStatus,
             .performanceStatus, .diagnosticsStatus, .autoRegulationStatus, .a9Status, .agentStatus, .gameStatus:
            return .readOnly
        case .navigate:
            return .navigation
        case .exportDiagnostics:
            return .localExport
        case .executeSuggestedGameMove:
            return .gameMutation
        case .refreshBLE, .startBLE, .stopBLE, .databaseIntegrity, .trimCaches,
             .restoreAutomaticPerformance, .activateAgentRuntime, .unloadAgentRuntime,
             .setVisualContext, .setAutoSaveReceivedImages, .setResourceFocus,
             .setAutoRegulationMode, .runAutoRegulationOnce:
            return .localMutation
        }
    }

    nonisolated static func authorize(
        _ command: VeilAppControlCommand,
        permissions: VeilAppControlPermissions,
        source: VeilAppControlSource = .directUser
    ) -> VeilAppControlDecision {
        let access = access(for: command)

        if source == .automaticRegulator {
            guard permissions.autoRegulationMode == .safeAutomatic else {
                return VeilAppControlDecision(
                    allowed: false,
                    access: access,
                    reason: "自动调控当前不是安全自动模式。"
                )
            }
            guard isAutomaticSafe(command) else {
                return VeilAppControlDecision(
                    allowed: false,
                    access: access,
                    reason: "该命令不属于自动调控安全白名单。"
                )
            }
            return VeilAppControlDecision(allowed: true, access: access, reason: nil)
        }

        switch access {
        case .readOnly, .navigation:
            return VeilAppControlDecision(allowed: true, access: access, reason: nil)
        case .localMutation:
            return VeilAppControlDecision(
                allowed: permissions.localMutationsEnabled,
                access: access,
                reason: permissions.localMutationsEnabled ? nil : "AI 控制中心已关闭本地工具动作。"
            )
        case .localExport:
            guard permissions.localMutationsEnabled else {
                return VeilAppControlDecision(allowed: false, access: access, reason: "AI 控制中心已关闭本地工具动作。")
            }
            guard permissions.diagnosticsExportEnabled else {
                return VeilAppControlDecision(allowed: false, access: access, reason: "AI 控制中心未允许诊断包导出。")
            }
            return VeilAppControlDecision(allowed: true, access: access, reason: nil)
        case .gameMutation:
            return VeilAppControlDecision(
                allowed: permissions.suggestedMoveExecutionEnabled,
                access: access,
                reason: permissions.suggestedMoveExecutionEnabled ? nil : "AI 控制中心未允许执行建议着法。"
            )
        }
    }

    nonisolated static func isAutomaticSafe(_ command: VeilAppControlCommand) -> Bool {
        switch command {
        case .setResourceFocus, .trimCaches, .refreshBLE:
            return true
        default:
            return false
        }
    }
}

struct VeilAppControlResult: Equatable, Sendable {
    let commandID: String
    let success: Bool
    let didMutate: Bool
    let message: String

    static func denied(_ command: VeilAppControlCommand, reason: String) -> VeilAppControlResult {
        VeilAppControlResult(commandID: command.id, success: false, didMutate: false, message: reason)
    }
}

enum VeilAppControlParser {
    static let advertisedCommands = [
        "/control help",
        "/control status",
        "/transport status",
        "/media status",
        "/performance status",
        "/diagnostics status",
        "/diagnostics export",
        "/autotune status",
        "/autotune off",
        "/autotune advise",
        "/autotune auto",
        "/autotune now",
        "/ble refresh",
        "/ble start",
        "/ble stop",
        "/db check",
        "/a9 status",
        "/agent status",
        "/game status",
        "/game move",
        "/control trim",
        "/performance auto",
        "/focus auto",
        "/focus communications",
        "/focus agent",
        "/focus game",
        "/open chats",
        "/open nearby",
        "/open games",
        "/open agent",
        "/open settings"
    ]

    nonisolated static func parse(_ raw: String) -> VeilAppControlCommand? {
        let text = normalized(raw)
        switch text {
        case "/control help", "控制帮助", "app控制帮助", "应用控制帮助", "你能控制什么", "帮我看看你能控制什么":
            return .controlHelp
        case "/control status", "app状态", "应用状态", "整体状态", "查看整体状态", "查看app状态", "看看app现在怎么样":
            return .overviewStatus
        case "/transport status", "传输状态", "蓝牙传输状态", "看看传输队列", "传输有没有堵", "看看蓝牙有没有堵":
            return .transportStatus
        case "/media status", "媒体状态", "图片传输状态", "图片策略", "看看图片传输设置":
            return .mediaStatus
        case "/performance status", "性能状态", "当前性能策略", "看看性能模式", "设备性能状态":
            return .performanceStatus
        case "/diagnostics status", "诊断状态", "日志状态", "看看日志", "诊断日志状态":
            return .diagnosticsStatus
        case "/diagnostics export", "导出诊断包", "生成诊断包", "导出日志包":
            return .exportDiagnostics
        case "/autotune status", "自动调控状态", "自调节状态", "看看自动调控":
            return .autoRegulationStatus
        case "/autotune off", "关闭自动调控", "关闭自调节":
            return .setAutoRegulationMode(.off)
        case "/autotune advise", "自动调控只建议", "自调节只建议", "只给调度建议":
            return .setAutoRegulationMode(.advisory)
        case "/autotune auto", "开启安全自动调控", "开启自动调控", "自动调节性能":
            return .setAutoRegulationMode(.safeAutomatic)
        case "/autotune now", "现在自动诊断", "立即自调节", "现在调一下":
            return .runAutoRegulationOnce
        case "/ble refresh", "刷新蓝牙", "刷新蓝牙链路", "刷新链路", "重新扫描蓝牙", "重新扫描附近设备", "刷新附近设备", "帮我重新扫描附近设备":
            return .refreshBLE
        case "/ble start", "启动蓝牙通信", "开始蓝牙通信", "启动ble", "启动 ble":
            return .startBLE
        case "/ble stop", "停止蓝牙通信", "暂停蓝牙通信", "停止ble", "停止 ble":
            return .stopBLE
        case "/db check", "检查数据库", "检查数据库完整性", "数据库完整性检查":
            return .databaseIntegrity
        case "/a9 status", "a9状态", "查看a9状态", "查看 a9 状态":
            return .a9Status
        case "/agent status", "灵核状态", "查看灵核状态":
            return .agentStatus
        case "/game status", "当前对局状态", "查看当前对局":
            return .gameStatus
        case "/game move", "执行建议着法", "执行推荐着法", "走推荐的一步":
            return .executeSuggestedGameMove
        case "/control trim", "清理缓存", "释放缓存", "清一下缓存", "释放本地运行时内存":
            return .trimCaches
        case "/performance auto", "恢复自动性能", "恢复自动性能策略", "省电一点", "降低性能开销", "恢复省电策略":
            return .restoreAutomaticPerformance
        case "/agent activate", "启动灵核", "启动灵核运行时", "预热灵核":
            return .activateAgentRuntime
        case "/agent unload", "卸载灵核", "卸载灵核运行时", "关闭本地对话运行时":
            return .unloadAgentRuntime
        case "/vision on", "开启视觉上下文", "打开视觉上下文":
            return .setVisualContext(true)
        case "/vision off", "关闭视觉上下文":
            return .setVisualContext(false)
        case "/media autosave on", "开启自动保存图片", "打开自动保存图片":
            return .setAutoSaveReceivedImages(true)
        case "/media autosave off", "关闭自动保存图片":
            return .setAutoSaveReceivedImages(false)
        case "/focus auto", "自动平衡", "恢复自动调度", "资源自动分配":
            return .setResourceFocus(.automatic)
        case "/focus communications", "通信优先", "传输优先", "优先保证蓝牙", "优先传照片":
            return .setResourceFocus(.communications)
        case "/focus agent", "灵核优先", "对话优先", "优先本地助手":
            return .setResourceFocus(.agent)
        case "/focus game", "游戏优先", "优先游戏计算":
            return .setResourceFocus(.game)
        case "/open chats", "打开对话", "回到对话", "去对话":
            return .navigate(.chats)
        case "/open nearby", "打开附近", "去附近", "打开附近设备":
            return .navigate(.nearby)
        case "/open games", "打开游戏", "去游戏", "进入游戏大厅":
            return .navigate(.games)
        case "/open agent", "打开灵核", "去灵核", "进入灵核":
            return .navigate(.agent)
        case "/open settings", "打开设置", "去设置", "进入设置":
            return .navigate(.settings)
        default:
            return nil
        }
    }

    nonisolated private static func normalized(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "　", with: " ")
            .replacingOccurrences(of: "？", with: "")
            .replacingOccurrences(of: "。", with: "")
            .lowercased()
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }
        return text
    }
}
