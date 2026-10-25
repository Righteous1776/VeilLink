import Foundation

/// An isolated, deterministic analyzer. It NEVER transmits packets, reads keys,
/// migrates databases, changes runtime authority, or modifies a user's records.
enum VeilMissionFeature: String, CaseIterable, Identifiable, Sendable {
    case linkHealth, transportSelection, meshRoute, alternateRoute, relayHopBudget
    case packetSizing, transferRecovery, congestionControl, retryPacing, trafficFairness
    case deliverySLO, storageRunway, keyReadiness, replayGuard, privacyFootprint
    case thermalGuard, batteryReserve, touchOcclusion, incidentCorrelation, capabilityFallback

    var id: String { rawValue }
    var title: String {
        switch self {
        case .linkHealth: return "链路健康评分"
        case .transportSelection: return "BLE / LAN 路径决策"
        case .meshRoute: return "Mesh 最优路径"
        case .alternateRoute: return "独立备用路径"
        case .relayHopBudget: return "中继跳数预算"
        case .packetSizing: return "MTU 安全分片"
        case .transferRecovery: return "断点恢复计划"
        case .congestionControl: return "拥塞窗口控制"
        case .retryPacing: return "自适应重试"
        case .trafficFairness: return "控制消息优先级"
        case .deliverySLO: return "消息交付可靠性"
        case .storageRunway: return "存储空间预测"
        case .keyReadiness: return "密钥与数据保护门禁"
        case .replayGuard: return "重放异常检查"
        case .privacyFootprint: return "遥测隐私风险"
        case .thermalGuard: return "设备热负载保护"
        case .batteryReserve: return "电量续航保护"
        case .touchOcclusion: return "触摸遮挡检测"
        case .incidentCorrelation: return "故障事件关联"
        case .capabilityFallback: return "能力降级协商"
        }
    }
    var group: String {
        switch self {
        case .linkHealth, .transportSelection, .meshRoute, .alternateRoute, .relayHopBudget: return "链路与路由"
        case .packetSizing, .transferRecovery, .congestionControl, .retryPacing, .trafficFairness: return "传输与恢复"
        case .deliverySLO, .storageRunway, .keyReadiness, .replayGuard, .privacyFootprint: return "可靠性与隐私"
        case .thermalGuard, .batteryReserve, .touchOcclusion, .incidentCorrelation, .capabilityFallback: return "设备与诊断"
        }
    }
}

enum VeilMissionSeverity: String, Sendable {
    case normal, caution, blocked
}

struct VeilMissionFinding: Equatable, Sendable, Identifiable {
    let feature: VeilMissionFeature
    let severity: VeilMissionSeverity
    let headline: String
    let value: String
    let explanation: String
    var id: String { feature.rawValue }
}

struct VeilMissionPeer: Equatable, Sendable {
    let id: String
    let rssi: Int
    let loss: Double             // 0...1; treated as unknown if outside range
    let latencyMs: Double
    let bleAvailable: Bool
    let lanAvailable: Bool
}

struct VeilMissionEdge: Equatable, Sendable {
    let from: String
    let to: String
    let cost: Double             // positive cost; not geographic distance
}

struct VeilMissionOverlay: Equatable, Sendable {
    let name: String
    let visible: Bool
    let interceptsTouches: Bool
    let decorative: Bool
}

enum VeilMissionThermal: String, Sendable {
    case nominal, fair, serious, critical
}

struct VeilMissionSnapshot: Sendable {
    var peers: [VeilMissionPeer]
    var edges: [VeilMissionEdge]
    var sourceNode: String
    var destinationNode: String
    var allowedHops: Int
    var mtu: Int
    var dataLength: Int
    var confirmedBytes: Int
    var queueDepth: Int
    var congestionWindow: Int
    var lossFraction: Double
    var ackSamplesMs: [Double]
    var attempts: Int
    var messageDeliverySeconds: [Double]
    var undeliveredMessages: Int
    var diskFreeBytes: Int64
    var projectedDailyBytes: Int64
    var databaseFilePresent: Bool
    var protectedDataAvailable: Bool
    var encryptionKeyAccessible: Bool
    var sequenceNumbers: [UInt64]
    var rawTouchCapture: Bool
    var sensitiveMetadataFields: Int
    var thermal: VeilMissionThermal
    var batteryFraction: Double
    var lowPowerMode: Bool
    var overlays: [VeilMissionOverlay]
    var warningEvents: [String]
    var knownCapabilities: Set<String>
    var requestedCapabilities: Set<String>
}

enum VeilMissionScenario: String, CaseIterable, Identifiable {
    case healthy = "正常链路"
    case degraded = "隔墙弱链路"
    case recovery = "恢复与迁移"
    var id: String { rawValue }

    /// Explicitly synthetic samples. Never represent these as live device telemetry.
    var snapshot: VeilMissionSnapshot {
        let degraded = self == .degraded
        let recovering = self == .recovery
        return VeilMissionSnapshot(
            peers: [
                .init(id: "P1", rssi: degraded ? -92 : -62, loss: degraded ? 0.24 : 0.01,
                      latencyMs: degraded ? 450 : 72, bleAvailable: true, lanAvailable: !degraded),
                .init(id: "P2", rssi: -73, loss: 0.04, latencyMs: 95,
                      bleAvailable: true, lanAvailable: false)
            ],
            edges: [
                .init(from: "self", to: "P1", cost: degraded ? 8 : 2),
                .init(from: "P1", to: "target", cost: 2),
                .init(from: "self", to: "P2", cost: 3),
                .init(from: "P2", to: "target", cost: 4)
            ],
            sourceNode: "self", destinationNode: "target", allowedHops: degraded ? 1 : 3,
            mtu: degraded ? 23 : 185, dataLength: 98_304,
            confirmedBytes: recovering ? 65_536 : 16_384,
            queueDepth: degraded ? 28 : 4,
            congestionWindow: 8, lossFraction: degraded ? 0.20 : 0.01,
            ackSamplesMs: degraded ? [80, 110, 470, 850] : [53, 61, 64, 75],
            attempts: degraded ? 5 : 1,
            messageDeliverySeconds: degraded ? [2, 4, 7, 32] : [0.4, 0.6, 0.8, 1.1],
            undeliveredMessages: degraded ? 3 : 0,
            diskFreeBytes: recovering ? 16_384_000 : 1_073_741_824,
            projectedDailyBytes: 4_194_304,
            databaseFilePresent: true,
            protectedDataAvailable: true,
            encryptionKeyAccessible: !recovering,
            sequenceNumbers: degraded ? [9, 10, 10, 8] : [9, 10, 11, 12],
            rawTouchCapture: degraded,
            sensitiveMetadataFields: degraded ? 2 : 0,
            thermal: degraded ? .serious : .nominal,
            batteryFraction: degraded ? 0.12 : 0.68,
            lowPowerMode: degraded,
            overlays: [.init(name: "Decorative glow", visible: true,
                             interceptsTouches: degraded, decorative: true)],
            warningEvents: degraded ?
                ["ble.timeout", "ble.timeout", "touch.cancel", "session.mismatch", "ble.timeout"] :
                ["ble.connected"],
            knownCapabilities: degraded ? ["ble", "text"] : ["ble", "lan", "text", "image"],
            requestedCapabilities: ["ble", "text", "image"]
        )
    }
}

enum VeilMissionControlEngine {
    private static func clamp(_ x: Double, _ low: Double = 0, _ high: Double = 1) -> Double {
        x.isFinite ? min(high, max(low, x)) : low
    }
    private static func result(_ feature: VeilMissionFeature, _ severity: VeilMissionSeverity,
                               _ headline: String, _ value: String, _ explanation: String) -> VeilMissionFinding {
        .init(feature: feature, severity: severity, headline: headline, value: value, explanation: explanation)
    }
    private static func safeCount(_ n: Int) -> Int { max(0, n) }

    /// Pure graph analysis, bounded to avoid huge/invalid graph payloads.
    static func shortestRoute(_ edges: [VeilMissionEdge], source: String,
                              destination: String, avoiding: Set<String> = []) -> ([String], Double)? {
        guard !source.isEmpty, !destination.isEmpty,
              !avoiding.contains(source), !avoiding.contains(destination),
              edges.count <= 1_024 else { return nil }
        if source == destination { return ([source], 0) }
        let valid = edges.filter {
            $0.cost.isFinite && $0.cost > 0 && !$0.from.isEmpty && !$0.to.isEmpty &&
            !avoiding.contains($0.from) && !avoiding.contains($0.to)
        }
        var nodes: Set<String> = [source, destination]
        for edge in valid { nodes.insert(edge.from); nodes.insert(edge.to) }
        guard nodes.count <= 256 else { return nil }
        var distance: [String: Double] = [source: 0]
        var previous: [String: String] = [:]
        var unvisited = nodes
        while !unvisited.isEmpty {
            guard let current = unvisited.min(by: {
                (distance[$0] ?? .infinity) < (distance[$1] ?? .infinity)
            }), let currentCost = distance[current] else { break }
            if current == destination { break }
            unvisited.remove(current)
            for edge in valid where edge.from == current && unvisited.contains(edge.to) {
                let candidate = currentCost + edge.cost
                if candidate < (distance[edge.to] ?? .infinity) {
                    distance[edge.to] = candidate
                    previous[edge.to] = current
                }
            }
        }
        guard let total = distance[destination], total.isFinite else { return nil }
        var route = [destination]
        while let before = previous[route[0]] {
            route.insert(before, at: 0)
            if route.count > nodes.count { return nil }
        }
        return route.first == source ? (route, total) : nil
    }

    static func analyze(_ feature: VeilMissionFeature, snapshot s: VeilMissionSnapshot) -> VeilMissionFinding {
        switch feature {
        case .linkHealth:
            guard let p = s.peers.first else { return result(feature, .blocked, "无可用链路", "—", "当前样本没有邻居链路数据。") }
            let rssi = clamp(Double(p.rssi + 100) / 55)
            let loss = clamp(p.loss)
            let latency = clamp(1 - p.latencyMs / 1_000)
            let score = Int((rssi * 0.45 + (1 - loss) * 0.35 + latency * 0.20) * 100)
            return result(feature, score < 45 ? .blocked : score < 72 ? .caution : .normal,
                          "邻居 \(p.id) 链路评估", "\(score)/100",
                          "依据 RSSI、丢包率、延迟加权计算；仅供调度参考，不保证实际距离。")
        case .transportSelection:
            guard let p = s.peers.first else { return result(feature, .blocked, "未检测到邻居", "不可选", "需要可达的配对设备。") }
            let selected = p.lanAvailable ? "LAN" : p.bleAvailable ? "BLE" : "无可用通道"
            return result(feature, selected == "无可用通道" ? .blocked : .normal, "推荐当前通道", selected,
                          "LAN 可用时优先大文件，BLE 保留控制与离线回退；实际选择必须通过安全会话授权。")
        case .meshRoute:
            guard let route = shortestRoute(s.edges, source: s.sourceNode, destination: s.destinationNode) else {
                return result(feature, .blocked, "无法规划 Mesh 路径", "无路径", "缺少可信的连通图或图数据无效。")
            }
            return result(feature, .normal, "最低代价路径", route.0.joined(separator: " → "),
                          "总代价 \(String(format: "%.1f", route.1))；规划结果不代表各节点已建立加密信任。")
        case .alternateRoute:
            guard let primary = shortestRoute(s.edges, source: s.sourceNode, destination: s.destinationNode) else {
                return result(feature, .blocked, "主路不可达", "无备线", "需要先有可达主路。")
            }
            let internalNodes = Set(primary.0.dropFirst().dropLast())
            guard let secondary = shortestRoute(s.edges, source: s.sourceNode, destination: s.destinationNode, avoiding: internalNodes) else {
                return result(feature, .caution, "没有节点独立备线", "单路径", "主路中继失效时需要等待重新发现。")
            }
            return result(feature, .normal, "节点独立备用路线", secondary.0.joined(separator: " → "),
                          "排除主路径的中间节点重新计算；不保证物理无线链路独立。")
        case .relayHopBudget:
            guard let route = shortestRoute(s.edges, source: s.sourceNode, destination: s.destinationNode) else {
                return result(feature, .blocked, "中继预算无法应用", "无路径", "不可使用未知路线推定成功传输。")
            }
            let hops = max(0, route.0.count - 1), budget = safeCount(s.allowedHops)
            return result(feature, hops > budget ? .blocked : .normal, "防止无界转发", "\(hops)/\(budget) 跳",
                          hops > budget ? "路线超过预算，应拒绝该候选路径。" : "跳数在预算内；仍须完成去重、TTL 与权限验证。")
        case .packetSizing:
            let payload = max(0, s.mtu - 3)
            guard payload > 0 else { return result(feature, .blocked, "MTU 无效", "0 B", "ATT 写入长度不可为负。") }
            let count = (safeCount(s.dataLength) + payload - 1) / payload
            return result(feature, payload < 40 ? .caution : .normal, "BLE ATT 理论载荷上限", "\(payload) B",
                          "约 \(count) 次 ATT 写入；真正加密分片需扣除 Wire 封装开销，绝不可直接使用该上限。")
        case .transferRecovery:
            let total = safeCount(s.dataLength), offset = min(total, safeCount(s.confirmedBytes))
            return result(feature, offset == total ? .normal : .caution, "断点恢复候选计划",
                          "\(max(0, total - offset)) B 待验证",
                          "从已认证检查点 \(offset) B 恢复；先核验原始密文、SHA-256 与会话连续性，不能盲信本地偏移。")
        case .congestionControl:
            let cwnd = max(1, min(4_096, s.congestionWindow))
            let next = clamp(s.lossFraction) > 0.08 ? max(1, cwnd / 2) : min(4_096, cwnd + 1)
            return result(feature, next < cwnd ? .caution : .normal, "AIMD 发送窗口建议", "\(cwnd) → \(next)",
                          "丢包高则乘性减小，否则缓慢增加；属于建议值，不修改活动发送队列。")
        case .retryPacing:
            let step = min(10, safeCount(s.attempts))
            let seconds = min(60, 1 << step)
            return result(feature, step >= 5 ? .caution : .normal, "指数退避上限", "\(seconds) s",
                          "建议以基础退避配合有界随机扰动；真实重连还须考虑应用前后台限制。")
        case .trafficFairness:
            let q = safeCount(s.queueDepth)
            let reserve = max(2, min(16, (q + 3) / 4))
            return result(feature, q > 20 ? .caution : .normal, "控制面保留配额", "\(reserve) 个槽位",
                          "优先 ACK、握手及控制包；为其他用户流量保留发送机会，防止图片压制聊天。")
        case .deliverySLO:
            let samples = s.messageDeliverySeconds.filter { $0.isFinite && $0 >= 0 }.sorted()
            guard !samples.isEmpty else { return result(feature, .caution, "样本不足", "—", "无法给出交付延迟百分位。") }
            let index = min(samples.count - 1, Int(ceil(Double(samples.count) * 0.95)) - 1)
            let p95 = samples[max(0,index)]
            return result(feature, p95 > 10 || s.undeliveredMessages > 0 ? .caution : .normal,
                          "最近消息 P95 延迟", String(format:"%.1f s",p95),
                          "未送达 \(safeCount(s.undeliveredMessages)) 条；样本量 \(samples.count)，小样本仅供诊断。")
        case .storageRunway:
            let free = max(0, s.diskFreeBytes), daily = max(0, s.projectedDailyBytes)
            guard daily > 0 else { return result(feature, .normal, "无有效增长率", "—", "需要非零的历史日增长估计。") }
            let days = min(Int64(100_000), free / daily)
            return result(feature, days < 7 ? .caution : .normal, "预计剩余本地存储", "\(days) 天",
                          "只使用可用空间与日增长量作线性估计；不得自动删除或清理任何聊天数据。")
        case .keyReadiness:
            guard s.databaseFilePresent else {
                return result(feature, .caution, "未发现数据库", "只读保护", "不得凭空创建替代数据库并覆盖旧身份。")
            }
            if !s.protectedDataAvailable {
                return result(feature, .blocked, "受保护数据暂不可用", "拒绝打开", "等待系统解锁后重试；禁止重建密钥。")
            }
            if !s.encryptionKeyAccessible {
                return result(feature, .blocked, "数据库存在但密钥不可读取", "拒绝重置", "保留原 SQLite 字节，检查签名/Keychain 访问组连续性。")
            }
            return result(feature, .normal, "数据访问前置条件具备", "可进一步验证", "这不是数据库解密成功的证明；下一步仍需验证密钥匹配及数据库完整性。")
        case .replayGuard:
            guard !s.sequenceNumbers.isEmpty else { return result(feature, .caution, "无序列样本", "—", "不能推断重放状态。") }
            let unique = Set(s.sequenceNumbers)
            let repeats = s.sequenceNumbers.count - unique.count
            let regression = zip(s.sequenceNumbers, s.sequenceNumbers.dropFirst()).filter { $0.1 < $0.0 }.count
            return result(feature, repeats + regression > 0 ? .caution : .normal,
                          "单链路序列异常", "\(repeats) 重复 / \(regression) 回退",
                          "仅发现异常线索；认证重放窗口由既有协议实现负责，这里不拒绝真实数据包。")
        case .privacyFootprint:
            let exposure = safeCount(s.sensitiveMetadataFields) + (s.rawTouchCapture ? 1 : 0)
            return result(feature, exposure > 0 ? .caution : .normal,
                          "诊断元数据最小化", "\(exposure) 项待检查",
                          "关闭不必要的原始触控记录，删除敏感字段；禁止输出明文、身份密钥或精确私人数据。")
        case .thermalGuard:
            let cap = s.thermal == .critical ? 0 : s.thermal == .serious ? 25 : s.thermal == .fair ? 60 : 100
            return result(feature, cap <= 25 ? .caution : .normal, "视觉/计算预算建议", "\(cap)%",
                          "系统热状态优先于强制特效。仅为计算建议，不控制 A9/A10 Governor。")
        case .batteryReserve:
            let fraction = clamp(s.batteryFraction)
            let budget = s.lowPowerMode || fraction < 0.15 ? 20 : fraction < 0.30 ? 55 : 100
            return result(feature, budget <= 20 ? .caution : .normal,
                          "后台任务建议预算", "\(budget)%",
                          "依据电量和低电量模式降低非必要任务；不承诺绕过 iOS 后台调度。")
        case .touchOcclusion:
            let risky = s.overlays.filter { $0.visible && $0.decorative && $0.interceptsTouches }
            return result(feature, risky.isEmpty ? .normal : .caution,
                          "不应接收触摸的装饰层", "\(risky.count) 处",
                          risky.isEmpty ? "样本未发现装饰层触摸截获。" :
                          "候选：\(risky.map(\.name).joined(separator: "、"))。需要真机命中路径验证，不直接更改视图层级。")
        case .incidentCorrelation:
            let group = Dictionary(grouping: s.warningEvents, by: { $0 })
            let sortedKeys = group.keys.sorted { lhs, rhs in
                let leftCount = group[lhs]?.count ?? 0
                let rightCount = group[rhs]?.count ?? 0
                if leftCount == rightCount { return lhs < rhs }
                return leftCount > rightCount
            }
            guard let topEvent = sortedKeys.first else {
                return result(feature, .normal, "没有警告样本", "0", "暂无可归类的事件。")
            }
            let topCount = group[topEvent]?.count ?? 0
            return result(feature, topCount >= 3 ? .caution : .normal,
                          "最高频异常事件", topEvent,
                          "发生 \(topCount) 次，合计 \(s.warningEvents.count) 条；同名计数不代表已证明因果关系。")
        case .capabilityFallback:
            let absent = s.requestedCapabilities.subtracting(s.knownCapabilities)
            if absent.isEmpty { return result(feature, .normal, "请求能力齐全", "全部可用", "实际调用前仍需实时 OS 权限与安全会话检查。") }
            return result(feature, .caution, "需要功能降级", "\(absent.count) 项",
                          "缺失：\(absent.sorted().joined(separator: "、"))。保持文本/BLE 等现有可用能力，不伪造授权。")
        }
    }

    static func analyzeAll(_ snapshot: VeilMissionSnapshot) -> [VeilMissionFinding] {
        VeilMissionFeature.allCases.map { analyze($0, snapshot: snapshot) }
    }
}
