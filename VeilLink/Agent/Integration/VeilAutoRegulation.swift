import Foundation

enum VeilAutoThermalLevel: Int, Codable, Comparable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    static func < (lhs: VeilAutoThermalLevel, rhs: VeilAutoThermalLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum VeilAutoRegulationSeverity: String, Codable, Sendable {
    case normal
    case attention
    case pressure
    case protection
}

enum VeilAutoRegulationAction: Equatable, Sendable {
    case setFocus(VeilAppResourceFocus)
    case trimCaches
    case refreshBLE

    var controlCommand: VeilAppControlCommand {
        switch self {
        case .setFocus(let focus): return .setResourceFocus(focus)
        case .trimCaches: return .trimCaches
        case .refreshBLE: return .refreshBLE
        }
    }
}

struct VeilAutoRegulationSnapshot: Equatable, Sendable {
    let mode: VeilAutoRegulationMode
    let thermal: VeilAutoThermalLevel
    let lowPowerMode: Bool
    let a9HealthScore: Int
    let pendingBytes: Int
    let controlPendingPackets: Int
    let maximumStallMilliseconds: Int
    let recoveringPeerCount: Int
    let connectedPeerCount: Int
    let currentFocus: VeilAppResourceFocus
    let visibleDestination: VeilAppDestination
    let agentGenerating: Bool
    let gameActive: Bool
    let manualFocusHoldActive: Bool
    let secondsSinceLastMutation: TimeInterval?
    let secondsSinceLastMaintenance: TimeInterval?
    let secondsSinceLastBLERepair: TimeInterval?
}

struct VeilAutoRegulationPlan: Equatable, Sendable {
    let severity: VeilAutoRegulationSeverity
    let summary: String
    let actions: [VeilAutoRegulationAction]

    static func idle(_ summary: String, severity: VeilAutoRegulationSeverity = .normal) -> VeilAutoRegulationPlan {
        VeilAutoRegulationPlan(severity: severity, summary: summary, actions: [])
    }
}

enum VeilAutoRegulationPolicy {
    static let mutationCooldown: TimeInterval = 15
    static let maintenanceCooldown: TimeInterval = 60
    static let bleRepairCooldown: TimeInterval = 20

    nonisolated static func evaluate(_ s: VeilAutoRegulationSnapshot) -> VeilAutoRegulationPlan {
        guard s.mode != .off else {
            return .idle("自动调控已关闭。")
        }

        let inMutationCooldown = (s.secondsSinceLastMutation ?? .infinity) < mutationCooldown
        let mayMaintain = (s.secondsSinceLastMaintenance ?? .infinity) >= maintenanceCooldown
        let mayRepairBLE = (s.secondsSinceLastBLERepair ?? .infinity) >= bleRepairCooldown
        let severeTransport = s.pendingBytes >= 384 * 1024
            || s.controlPendingPackets >= 8
            || s.maximumStallMilliseconds >= 3_000
            || s.recoveringPeerCount >= 2
        let pressuredTransport = severeTransport
            || s.pendingBytes >= 128 * 1024
            || s.controlPendingPackets >= 3
            || s.maximumStallMilliseconds >= 1_500
            || s.recoveringPeerCount >= 1
        let recoveringBadly = s.maximumStallMilliseconds >= 3_500 || s.recoveringPeerCount >= 2

        // Thermal protection can override a manual performance focus because it only applies
        // reversible local scheduling/cache actions and never stops BLE or changes user data.
        if s.thermal == .critical {
            var actions: [VeilAutoRegulationAction] = []
            if s.currentFocus != .automatic { actions.append(.setFocus(.automatic)) }
            if mayMaintain { actions.append(.trimCaches) }
            return VeilAutoRegulationPlan(
                severity: .protection,
                summary: "温控达到 critical：回到自动平衡并尽量释放临时缓存。",
                actions: actions
            )
        }

        if s.thermal == .serious {
            var actions: [VeilAutoRegulationAction] = []
            let desired: VeilAppResourceFocus = pressuredTransport ? .communications : .automatic
            if s.currentFocus != desired { actions.append(.setFocus(desired)) }
            if mayMaintain { actions.append(.trimCaches) }
            return VeilAutoRegulationPlan(
                severity: .protection,
                summary: pressuredTransport
                    ? "温控 serious 且传输有压力：优先保住通信并释放临时缓存。"
                    : "温控 serious：降低可选计算并释放临时缓存。",
                actions: actions
            )
        }

        // After a user manually chooses a focus, non-thermal automation backs off for 90 s.
        if s.manualFocusHoldActive {
            if recoveringBadly && mayRepairBLE {
                return VeilAutoRegulationPlan(
                    severity: .attention,
                    summary: "人工焦点保护中；仅检测到链路恢复异常，允许刷新 BLE。",
                    actions: [.refreshBLE]
                )
            }
            return .idle("人工焦点保护中，自动调控暂不覆盖你的资源选择。", severity: .attention)
        }

        if inMutationCooldown {
            return .idle("刚执行过自动调控，处于防抖冷却期。", severity: .attention)
        }

        if severeTransport {
            var actions: [VeilAutoRegulationAction] = []
            if s.currentFocus != .communications { actions.append(.setFocus(.communications)) }
            if recoveringBadly && mayRepairBLE { actions.append(.refreshBLE) }
            return VeilAutoRegulationPlan(
                severity: .pressure,
                summary: "BLE 队列或恢复压力较高：切到通信优先。",
                actions: actions
            )
        }

        // Hysteresis: once communications focus is active, keep it until backlog falls well below
        // the entry threshold so the scheduler does not oscillate every sampling tick.
        if s.currentFocus == .communications,
           s.pendingBytes >= 64 * 1024 || s.controlPendingPackets >= 1 || s.maximumStallMilliseconds >= 700 {
            return .idle("通信压力正在回落，保持通信优先直到队列进一步清空。", severity: .attention)
        }

        if pressuredTransport {
            let actions: [VeilAutoRegulationAction] = s.currentFocus == .communications ? [] : [.setFocus(.communications)]
            return VeilAutoRegulationPlan(
                severity: .attention,
                summary: "检测到中等传输压力：暂时提高通信调度优先级。",
                actions: actions
            )
        }

        if s.lowPowerMode || s.a9HealthScore < 55 {
            var actions: [VeilAutoRegulationAction] = []
            if s.currentFocus != .automatic { actions.append(.setFocus(.automatic)) }
            if mayMaintain { actions.append(.trimCaches) }
            return VeilAutoRegulationPlan(
                severity: .attention,
                summary: s.lowPowerMode ? "系统低电量模式开启：回到自动平衡。" : "A9 健康度偏低：回到自动平衡。",
                actions: actions
            )
        }

        let desired: VeilAppResourceFocus
        if s.visibleDestination == .games && s.gameActive {
            desired = .game
        } else if s.visibleDestination == .agent && s.agentGenerating {
            desired = .agent
        } else {
            desired = .automatic
        }

        if desired == s.currentFocus {
            return .idle("运行状态稳定，无需调整。")
        }
        return VeilAutoRegulationPlan(
            severity: .normal,
            summary: "根据当前前台任务调整为“\(desired.title)”。",
            actions: [.setFocus(desired)]
        )
    }
}
