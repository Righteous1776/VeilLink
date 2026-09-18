import Foundation

enum VeilA9Light: Int, Codable, CaseIterable, Sendable {
    case green = 0
    case yellow = 1
    case red = 2

    var title: String {
        switch self {
        case .green: return "绿色"
        case .yellow: return "黄色"
        case .red: return "红色"
        }
    }
}

enum VeilA9Level: Int, Codable, CaseIterable, Comparable, Sendable {
    case l0Observe = 0
    case l1Advisory = 1
    case l2Review = 2
    case l3Priority = 3
    case l4HoldRecommendation = 4
    case l5Emergency = 5

    static func < (lhs: VeilA9Level, rhs: VeilA9Level) -> Bool { lhs.rawValue < rhs.rawValue }

    var shortTitle: String { "L\(rawValue)" }

    var title: String {
        switch self {
        case .l0Observe: return "观察"
        case .l1Advisory: return "提示"
        case .l2Review: return "复核"
        case .l3Priority: return "优先处理"
        case .l4HoldRecommendation: return "暂停建议"
        case .l5Emergency: return "紧急升级"
        }
    }
}

enum VeilA9Severity: String, Codable, CaseIterable, Sendable {
    case p0 = "P0"
    case p1 = "P1"
    case p2 = "P2"
    case p3 = "P3"
}

struct VeilA9Issue: Identifiable, Equatable, Sendable {
    let code: String
    let severity: VeilA9Severity
    let source: String
    let detail: String

    var id: String { "\(severity.rawValue):\(source):\(code)" }
}

enum VeilA9DatabaseIntegrity: Equatable, Sendable {
    case unchecked
    case ok
    case failed

    var title: String {
        switch self {
        case .unchecked: return "未自检"
        case .ok: return "正常"
        case .failed: return "异常"
        }
    }
}

enum VeilA9ThermalLevel: Int, Codable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
}

struct VeilA9Input: Equatable, Sendable {
    var bluetoothRunning = false
    var connectedPeerCount = 0
    var trackedPeerCount = 0
    var recoveringPeerCount = 0
    var weakPeerCount = 0
    var marginalPeerCount = 0
    var minimumLinkHealth: Int?
    var maximumReconnectAttempt = 0
    var pendingBytes = 0
    var controlPendingPackets = 0
    var maximumStallMilliseconds = 0
    var agentUnavailable = false
    var agentCooling = false
    var agentHasFailure = false
    var thermalLevel: VeilA9ThermalLevel = .nominal
    var lowPowerMode = false
    var databaseIntegrity: VeilA9DatabaseIntegrity = .unchecked
}

struct VeilA9Packet: Equatable, Sendable {
    let light: VeilA9Light
    let p0: Int
    let p1: Int
    let p2: Int
    let p3: Int
    let riskBP: Int
    let persistenceRuns: Int
    let blocker: Bool
    let healthBP: Int
    let issues: [VeilA9Issue]
}

struct VeilA9Decision: Equatable, Sendable {
    let light: VeilA9Light
    let level: VeilA9Level
    let reasonCode: String
    let healthScore: Int
    let riskPoints: Double
    let persistenceRuns: Int
    let issues: [VeilA9Issue]
    let latticeIndex: Int

    static let initial = VeilA9Decision(
        light: .green,
        level: .l0Observe,
        reasonCode: "GREEN_NORMAL",
        healthScore: 100,
        riskPoints: 0,
        persistenceRuns: 0,
        issues: [],
        latticeIndex: 0
    )
}

/// VeilLink adaptation of the DBH A9 144-state advisory lattice.
///
/// Deliberate removals from the database chip:
/// - no packet/release/contract/decision digests in the runtime hot path;
/// - no attestation envelope or protocol codec;
/// - no Canonical/Freeze/Cutover semantics;
/// - no Python/native shared object dependency.
///
/// The lattice remains advisory-only. It cannot mutate transport, storage, games or agent state.
enum VeilA9Lattice {
    static let persistentRunThreshold = 3
    static let redRiskThresholdBP = 2_800

    struct Cell: Equatable, Sendable {
        let level: VeilA9Level
        let reasonCode: String
    }

    static let cells: [Cell] = {
        var result = Array(repeating: Cell(level: .l0Observe, reasonCode: "GREEN_NORMAL"), count: 144)
        for light in 0..<3 {
            for p0 in 0..<2 {
                for p1Bucket in 0..<3 {
                    for blocker in 0..<2 {
                        for persistent in 0..<2 {
                            for redRisk in 0..<2 {
                                var level: VeilA9Level
                                var reason: String
                                if p0 > 0 {
                                    level = .l5Emergency
                                    reason = "P0_HARD_BREAK"
                                } else if light == VeilA9Light.red.rawValue && blocker > 0 {
                                    level = .l4HoldRecommendation
                                    reason = "RED_WITH_BLOCKER"
                                } else if light == VeilA9Light.red.rawValue {
                                    level = .l3Priority
                                    reason = "RED_NO_BLOCKER"
                                } else if light == VeilA9Light.yellow.rawValue && (p1Bucket > 0 || persistent > 0) {
                                    level = .l2Review
                                    reason = "YELLOW_PERSISTENT_OR_P1"
                                } else if light == VeilA9Light.yellow.rawValue {
                                    level = .l1Advisory
                                    reason = "YELLOW_ADVISORY"
                                } else {
                                    level = .l0Observe
                                    reason = "GREEN_NORMAL"
                                }

                                let floor: VeilA9Level
                                if p0 > 0 {
                                    floor = .l5Emergency
                                } else if blocker > 0 && light == VeilA9Light.red.rawValue {
                                    floor = .l4HoldRecommendation
                                } else if p1Bucket >= 2 || redRisk > 0 {
                                    floor = .l3Priority
                                } else {
                                    floor = .l0Observe
                                }
                                if level < floor {
                                    level = floor
                                    reason = "SAFETY_FLOOR_OVERRIDE"
                                }
                                result[index(
                                    light: light,
                                    hasP0: p0 > 0,
                                    p1Count: p1Bucket,
                                    blocker: blocker > 0,
                                    persistent: persistent > 0,
                                    redRisk: redRisk > 0
                                )] = Cell(level: level, reasonCode: reason)
                            }
                        }
                    }
                }
            }
        }
        return result
    }()

    struct Axes: Equatable, Sendable {
        let light: VeilA9Light
        let hasP0: Bool
        let p1Bucket: Int
        let blocker: Bool
        let persistent: Bool
        let redRisk: Bool
    }

    static func axes(for index: Int) -> Axes? {
        guard cells.indices.contains(index), let light = VeilA9Light(rawValue: index % 3) else { return nil }
        return Axes(
            light: light,
            hasP0: ((index / 3) % 2) == 1,
            p1Bucket: (index / 6) % 3,
            blocker: ((index / 18) % 2) == 1,
            persistent: ((index / 36) % 2) == 1,
            redRisk: ((index / 72) % 2) == 1
        )
    }

    static func index(
        light: Int,
        hasP0: Bool,
        p1Count: Int,
        blocker: Bool,
        persistent: Bool,
        redRisk: Bool
    ) -> Int {
        let p1Bucket = p1Count <= 0 ? 0 : (p1Count == 1 ? 1 : 2)
        return light
            + 3 * (hasP0 ? 1 : 0)
            + 6 * p1Bucket
            + 18 * (blocker ? 1 : 0)
            + 36 * (persistent ? 1 : 0)
            + 72 * (redRisk ? 1 : 0)
    }

    static func decide(_ packet: VeilA9Packet) -> VeilA9Decision {
        let index = index(
            light: packet.light.rawValue,
            hasP0: packet.p0 > 0,
            p1Count: packet.p1,
            blocker: packet.blocker,
            persistent: packet.persistenceRuns >= persistentRunThreshold,
            redRisk: packet.riskBP >= redRiskThresholdBP
        )
        let cell = cells[index]
        return VeilA9Decision(
            light: packet.light,
            level: cell.level,
            reasonCode: cell.reasonCode,
            healthScore: max(0, min(100, packet.healthBP / 10)),
            riskPoints: Double(packet.riskBP) / 100,
            persistenceRuns: packet.persistenceRuns,
            issues: packet.issues,
            latticeIndex: index
        )
    }
}


enum VeilA9Classifier {
    static func makePacket(input: VeilA9Input, persistenceRuns: Int) -> VeilA9Packet {
        var issues: [VeilA9Issue] = []

        func add(_ severity: VeilA9Severity, _ source: String, _ code: String, _ detail: String) {
            issues.append(VeilA9Issue(code: code, severity: severity, source: source, detail: detail))
        }

        if input.databaseIntegrity == .failed {
            add(.p0, "storage", "SQLITE_INTEGRITY_FAILED", "本地 SQLite 完整性自检未通过")
        }

        if input.maximumStallMilliseconds >= 20_000 && input.controlPendingPackets > 0 {
            add(.p1, "ble", "CONTROL_QUEUE_STALLED", "控制队列持续停滞 ≥20 秒")
        } else if input.maximumStallMilliseconds >= 8_000 && input.controlPendingPackets > 0 {
            add(.p2, "ble", "CONTROL_QUEUE_SLOW", "控制队列持续停滞 ≥8 秒")
        }

        if input.maximumReconnectAttempt >= 6 && input.recoveringPeerCount > 0 {
            add(.p1, "ble", "RECONNECT_PERSISTENT", "目标设备连续自动重连 ≥6 次")
        } else if input.maximumReconnectAttempt >= 3 && input.recoveringPeerCount > 0 {
            add(.p2, "ble", "RECONNECT_REPEATED", "目标设备正在重复重连")
        } else if input.recoveringPeerCount > 0 {
            add(.p3, "ble", "RECONNECT_ACTIVE", "存在正在恢复的目标设备")
        }

        if input.controlPendingPackets >= 64 {
            add(.p1, "ble", "CONTROL_BACKLOG_HIGH", "控制消息积压 ≥64 包")
        } else if input.controlPendingPackets >= 16 {
            add(.p2, "ble", "CONTROL_BACKLOG", "控制消息出现明显积压")
        }

        if input.pendingBytes >= 2 * 1_024 * 1_024 {
            add(.p2, "ble", "QUEUE_PRESSURE_HIGH", "发送队列 ≥2 MB")
        } else if input.pendingBytes >= 512 * 1_024 {
            add(.p3, "ble", "QUEUE_PRESSURE", "发送队列 ≥512 KB")
        }

        if input.weakPeerCount > 0 {
            add(.p2, "ble", "WEAK_LINK", "存在弱 BLE 链路")
        } else if input.marginalPeerCount > 0 {
            add(.p3, "ble", "MARGINAL_LINK", "存在一般质量 BLE 链路")
        }

        if let minimumLinkHealth = input.minimumLinkHealth, minimumLinkHealth < 30 {
            add(.p2, "ble", "LINK_HEALTH_LOW", "最低链路健康分低于 30")
        }

        if input.agentUnavailable && input.agentHasFailure {
            add(.p2, "agent", "AGENT_RUNTIME_FAILED", "本地 Agent 运行时不可用且记录了失败")
        } else if input.agentUnavailable {
            add(.p3, "agent", "AGENT_RUNTIME_UNAVAILABLE", "本地 Agent 运行时当前不可用")
        } else if input.agentCooling {
            add(.p3, "agent", "AGENT_RUNTIME_LIMITED", "本地 Agent 处于受限/冷却状态")
        }

        switch input.thermalLevel {
        case .critical:
            add(.p1, "system", "THERMAL_CRITICAL", "设备温控处于 critical")
        case .serious:
            add(.p2, "system", "THERMAL_SERIOUS", "设备温控处于 serious")
        case .fair:
            add(.p3, "system", "THERMAL_FAIR", "设备温度升高")
        case .nominal:
            break
        }

        if input.lowPowerMode {
            add(.p3, "system", "LOW_POWER_MODE", "系统低电量模式已开启")
        }

        let p0 = issues.filter { $0.severity == .p0 }.count
        let p1 = issues.filter { $0.severity == .p1 }.count
        let p2 = issues.filter { $0.severity == .p2 }.count
        let p3 = issues.filter { $0.severity == .p3 }.count
        let riskPoints = p0 * 40 + p1 * 12 + p2 * 4 + p3
        let riskBP = riskPoints * 100
        let healthBP = max(0, 1_000 - p0 * 500 - p1 * 160 - p2 * 70 - p3 * 20)
        let blocker = p0 > 0 || (input.maximumStallMilliseconds >= 20_000 && input.controlPendingPackets > 0)

        let light: VeilA9Light
        if p0 > 0 || riskBP >= VeilA9Lattice.redRiskThresholdBP || healthBP < 500 {
            light = .red
        } else if !issues.isEmpty || healthBP < 800 {
            light = .yellow
        } else {
            light = .green
        }

        return VeilA9Packet(
            light: light,
            p0: p0,
            p1: p1,
            p2: p2,
            p3: p3,
            riskBP: riskBP,
            persistenceRuns: persistenceRuns,
            blocker: blocker,
            healthBP: healthBP,
            issues: issues
        )
    }
}
