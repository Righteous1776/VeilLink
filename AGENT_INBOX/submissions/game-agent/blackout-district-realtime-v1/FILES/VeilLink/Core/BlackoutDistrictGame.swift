import Foundation

enum BlackoutOutcome: Equatable, Sendable {
    case running
    case stabilized
    case gridCollapse
    case timeExpired
}

struct BlackoutInput: Equatable, Sendable {
    var throttle: Double
    var steering: Double
    var repairing: Bool

    init(
        throttle: Double = 0,
        steering: Double = 0,
        repairing: Bool = false
    ) {
        self.throttle = min(1, max(-1, throttle))
        self.steering = min(1, max(-1, steering))
        self.repairing = repairing
    }
}

struct BlackoutGridNode: Equatable, Sendable, Identifiable {
    let id: Int
    let name: String
    let x: Double
    let y: Double
    let demand: Double
    let buildingCount: Int
    let critical: Bool
    var health: Double
    var repairProgress: Double
    var faulted: Bool
    var powered: Bool
}

struct BlackoutGridEdge: Equatable, Sendable {
    let a: Int
    let b: Int
}

struct BlackoutPuddle: Equatable, Sendable {
    let x: Double
    let y: Double
    let radius: Double
    let drag: Double
}

struct BlackoutEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case surge(Int)
        case faulted(Int)
        case repairStarted(Int)
        case repaired(Int)
        case districtPowered(Int)
        case districtDarkened(Int)
        case radio(String)
        case stabilized
        case gridCollapse
        case timeExpired
    }

    let tick: Int
    let kind: Kind
}

struct BlackoutSnapshot: Equatable, Sendable {
    let tick: Int
    let vehicleX: Double
    let vehicleY: Double
    let speed: Double
    let heading: Double
    let gridStability: Double
    let poweredNodes: Int
    let totalNodes: Int
    let litBuildings: Int
    let totalBuildings: Int
    let activeFaults: Int
    let repairTarget: Int?
    let repairProgress: Double
    let timeRemaining: Double
    let storm: Double
    let outcome: BlackoutOutcome
    let lastLine: String?
}

struct BlackoutDistrictState: Equatable, Sendable {
    static let fixedDelta = 1.0 / 60.0
    static let worldWidth = 2_400.0
    static let worldHeight = 1_800.0
    static let timeLimitTicks = 60 * 210

    let seed: UInt64
    let edges: [BlackoutGridEdge]
    let puddles: [BlackoutPuddle]

    private(set) var nodes: [BlackoutGridNode]
    private(set) var tick = 0
    private(set) var vehicleX = 220.0
    private(set) var vehicleY = 1_520.0
    private(set) var velocityX = 0.0
    private(set) var velocityY = 0.0
    private(set) var heading = 0.0
    private(set) var repairTarget: Int?
    private(set) var stableTicks = 0
    private(set) var events: [BlackoutEvent] = []
    private(set) var lastLine: String?
    private(set) var outcome: BlackoutOutcome = .running

    init(seed: UInt64) {
        self.seed = seed

        nodes = [
            .init(id: 0, name: "北站主变", x: 310, y: 1_470, demand: 0.35, buildingCount: 4, critical: true, health: 1, repairProgress: 0, faulted: false, powered: true),
            .init(id: 1, name: "旧城西", x: 720, y: 1_420, demand: 0.82, buildingCount: 13, critical: false, health: 0.78, repairProgress: 0, faulted: false, powered: true),
            .init(id: 2, name: "商业街", x: 1_180, y: 1_380, demand: 1.08, buildingCount: 16, critical: false, health: 0.66, repairProgress: 0, faulted: false, powered: true),
            .init(id: 3, name: "河西住宅", x: 1_720, y: 1_360, demand: 0.92, buildingCount: 15, critical: false, health: 0.72, repairProgress: 0, faulted: false, powered: true),
            .init(id: 4, name: "社区医院", x: 2_050, y: 1_010, demand: 1.18, buildingCount: 10, critical: true, health: 0.58, repairProgress: 0, faulted: false, powered: true),
            .init(id: 5, name: "工业仓区", x: 1_580, y: 820, demand: 1.12, buildingCount: 12, critical: false, health: 0.62, repairProgress: 0, faulted: false, powered: true),
            .init(id: 6, name: "南门街区", x: 1_020, y: 760, demand: 0.84, buildingCount: 14, critical: false, health: 0.70, repairProgress: 0, faulted: false, powered: true),
            .init(id: 7, name: "学校片区", x: 560, y: 700, demand: 0.74, buildingCount: 11, critical: true, health: 0.69, repairProgress: 0, faulted: false, powered: true),
            .init(id: 8, name: "河东住宅", x: 1_420, y: 360, demand: 0.76, buildingCount: 13, critical: false, health: 0.63, repairProgress: 0, faulted: false, powered: true)
        ]

        edges = [
            .init(a: 0, b: 1),
            .init(a: 1, b: 2),
            .init(a: 2, b: 3),
            .init(a: 3, b: 4),
            .init(a: 2, b: 6),
            .init(a: 6, b: 7),
            .init(a: 6, b: 5),
            .init(a: 5, b: 4),
            .init(a: 5, b: 8),
            .init(a: 7, b: 8)
        ]

        puddles = [
            .init(x: 520, y: 1_160, radius: 115, drag: 0.30),
            .init(x: 1_120, y: 1_040, radius: 145, drag: 0.38),
            .init(x: 1_810, y: 1_170, radius: 120, drag: 0.34),
            .init(x: 1_380, y: 610, radius: 135, drag: 0.42),
            .init(x: 760, y: 440, radius: 105, drag: 0.27)
        ]

        recalculatePower(emitEvents: false)
    }

    var isFinished: Bool {
        outcome != .running
    }

    var stormIntensity: Double {
        let a = (sin(Double(tick) * 0.0047 + Double(seed % 67) * 0.041) + 1) * 0.5
        let b = (sin(Double(tick) * 0.011 + Double(seed % 41) * 0.089) + 1) * 0.5
        return min(1, max(0, 0.32 + a * 0.35 + b * 0.20))
    }

    var gridStability: Double {
        let health = nodes.reduce(0.0) { $0 + $1.health } / Double(max(1, nodes.count))
        let powered = Double(nodes.filter(\.powered).count) / Double(max(1, nodes.count))
        return min(1, max(0, health * 0.58 + powered * 0.42))
    }

    mutating func step(input: BlackoutInput) {
        guard outcome == .running else { return }

        tick += 1
        events.removeAll(keepingCapacity: true)

        updateVehicle(input: input)
        applyStormStress()
        updateRepair(input: input)
        recalculatePower(emitEvents: true)
        resolveOutcome()
    }

    func snapshot() -> BlackoutSnapshot {
        let targetProgress: Double
        if let repairTarget,
           let node = nodes.first(where: { $0.id == repairTarget }) {
            targetProgress = node.repairProgress
        } else {
            targetProgress = 0
        }

        return BlackoutSnapshot(
            tick: tick,
            vehicleX: vehicleX,
            vehicleY: vehicleY,
            speed: hypot(velocityX, velocityY),
            heading: heading,
            gridStability: gridStability,
            poweredNodes: nodes.filter(\.powered).count,
            totalNodes: nodes.count,
            litBuildings: nodes.filter(\.powered).reduce(0) { $0 + $1.buildingCount },
            totalBuildings: nodes.reduce(0) { $0 + $1.buildingCount },
            activeFaults: nodes.filter(\.faulted).count,
            repairTarget: repairTarget,
            repairProgress: targetProgress,
            timeRemaining: max(0, Double(Self.timeLimitTicks - tick) * Self.fixedDelta),
            storm: stormIntensity,
            outcome: outcome,
            lastLine: lastLine
        )
    }

    private mutating func updateVehicle(input: BlackoutInput) {
        let puddleFactor = tractionFactorAtVehicle()
        let acceleration = 270 * puddleFactor
        let rotationRate = 2.05 * max(0.28, min(1, hypot(velocityX, velocityY) / 70 + 0.25))

        heading += input.steering * rotationRate * Self.fixedDelta

        velocityX += cos(heading) * input.throttle * acceleration * Self.fixedDelta
        velocityY += sin(heading) * input.throttle * acceleration * Self.fixedDelta

        let damping = pow(0.955 - (1 - puddleFactor) * 0.018, Self.fixedDelta * 60)
        velocityX *= damping
        velocityY *= damping

        let maxSpeed = 168 * puddleFactor + 42
        let speed = hypot(velocityX, velocityY)
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            velocityX *= scale
            velocityY *= scale
        }

        vehicleX = min(Self.worldWidth, max(0, vehicleX + velocityX * Self.fixedDelta))
        vehicleY = min(Self.worldHeight, max(0, vehicleY + velocityY * Self.fixedDelta))
    }

    private func tractionFactorAtVehicle() -> Double {
        for puddle in puddles {
            if hypot(vehicleX - puddle.x, vehicleY - puddle.y) <= puddle.radius {
                return max(0.45, 1 - puddle.drag)
            }
        }
        return 1
    }

    private mutating func applyStormStress() {
        guard tick % 90 == 0 else { return }

        let storm = stormIntensity
        let candidates = nodes.indices.filter { index in
            index != 0 && !nodes[index].faulted
        }

        guard !candidates.isEmpty else { return }

        let salt = UInt64(tick / 90)
        let selected = candidates[Int(deterministicUnit(salt: salt) * Double(candidates.count)) % candidates.count]
        let surge = 0.018 + storm * 0.032 + nodes[selected].demand * 0.008

        nodes[selected].health = max(0, nodes[selected].health - surge)
        events.append(.init(tick: tick, kind: .surge(nodes[selected].id)))

        if nodes[selected].health <= 0.28 {
            nodes[selected].faulted = true
            nodes[selected].repairProgress = 0
            events.append(.init(tick: tick, kind: .faulted(nodes[selected].id)))

            let line = nodes[selected].critical
                ? "调度：关键节点 \(nodes[selected].name) 失电。"
                : "调度：\(nodes[selected].name) 跳闸。"

            lastLine = line
            events.append(.init(tick: tick, kind: .radio(line)))
        }
    }

    private mutating func updateRepair(input: BlackoutInput) {
        let speed = hypot(velocityX, velocityY)
        let nearby = nodes.indices
            .filter { nodes[$0].faulted }
            .filter { hypot(nodes[$0].x - vehicleX, nodes[$0].y - vehicleY) <= 105 }
            .min { lhs, rhs in
                hypot(nodes[lhs].x - vehicleX, nodes[lhs].y - vehicleY) <
                hypot(nodes[rhs].x - vehicleX, nodes[rhs].y - vehicleY)
            }

        guard input.repairing,
              speed <= 22,
              let index = nearby else {
            repairTarget = nil
            return
        }

        if repairTarget != nodes[index].id {
            repairTarget = nodes[index].id
            events.append(.init(tick: tick, kind: .repairStarted(nodes[index].id)))
        }

        let rate = nodes[index].critical ? 1.0 / 210.0 : 1.0 / 160.0
        nodes[index].repairProgress = min(1, nodes[index].repairProgress + rate)

        if nodes[index].repairProgress >= 1 {
            nodes[index].faulted = false
            nodes[index].health = max(0.88, nodes[index].health)
            nodes[index].repairProgress = 0
            repairTarget = nil

            let line = nodes[index].critical
                ? "调度：\(nodes[index].name) 恢复。那一片灯又亮了。"
                : "调度：\(nodes[index].name) 已重新并网。"

            lastLine = line
            events.append(.init(tick: tick, kind: .repaired(nodes[index].id)))
            events.append(.init(tick: tick, kind: .radio(line)))
        }
    }

    private mutating func recalculatePower(emitEvents: Bool) {
        let previous = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.powered) })

        for index in nodes.indices {
            nodes[index].powered = false
        }

        guard !nodes[0].faulted,
              nodes[0].health > 0.20 else {
            if emitEvents {
                emitPowerTransitions(previous: previous)
            }
            return
        }

        var queue = [0]
        var visited: Set<Int> = [0]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            nodes[current].powered = !nodes[current].faulted

            for neighborID in neighbors(of: nodes[current].id) {
                guard let neighborIndex = nodes.firstIndex(where: { $0.id == neighborID }),
                      !visited.contains(neighborID),
                      !nodes[neighborIndex].faulted,
                      nodes[neighborIndex].health > 0.20 else {
                    continue
                }

                visited.insert(neighborID)
                queue.append(neighborIndex)
            }
        }

        let poweredDemand = nodes.filter(\.powered).reduce(0.0) { $0 + $1.demand }
        let capacity = 6.9 * (0.72 + nodes[0].health * 0.28)

        if poweredDemand > capacity {
            let overload = min(0.12, (poweredDemand - capacity) / capacity * 0.06)
            for index in nodes.indices where nodes[index].powered && index != 0 {
                nodes[index].health = max(0, nodes[index].health - overload * nodes[index].demand)
                if nodes[index].health <= 0.24 {
                    nodes[index].faulted = true
                    nodes[index].powered = false
                }
            }
        }

        if emitEvents {
            emitPowerTransitions(previous: previous)
        }
    }

    private mutating func emitPowerTransitions(previous: [Int: Bool]) {
        for node in nodes {
            let wasPowered = previous[node.id] ?? false

            if !wasPowered && node.powered {
                events.append(.init(tick: tick, kind: .districtPowered(node.id)))
            } else if wasPowered && !node.powered {
                events.append(.init(tick: tick, kind: .districtDarkened(node.id)))
            }
        }
    }

    private func neighbors(of id: Int) -> [Int] {
        edges.compactMap { edge in
            if edge.a == id { return edge.b }
            if edge.b == id { return edge.a }
            return nil
        }
    }

    private mutating func resolveOutcome() {
        let criticalDown = nodes.filter { $0.critical && !$0.powered }.count

        if !nodes[0].powered && criticalDown >= 2 {
            outcome = .gridCollapse
            lastLine = "调度：主网失稳。街区进入全黑。"
            events.append(.init(tick: tick, kind: .gridCollapse))
            return
        }

        if gridStability >= 0.88 &&
            nodes.filter(\.powered).count >= 8 &&
            nodes.filter(\.faulted).isEmpty {
            stableTicks += 1
        } else {
            stableTicks = 0
        }

        if stableTicks >= 60 * 8 {
            outcome = .stabilized
            lastLine = "调度：负载稳定。街区恢复常态供电。"
            events.append(.init(tick: tick, kind: .stabilized))
        } else if tick >= Self.timeLimitTicks {
            outcome = .timeExpired
            lastLine = "调度：风暴进入第二阶段。维修窗口关闭。"
            events.append(.init(tick: tick, kind: .timeExpired))
        }
    }

    private func deterministicUnit(salt: UInt64) -> Double {
        Double(mix(seed ^ salt) & 0xFFFF) / Double(0xFFFF)
    }

    private func mix(_ input: UInt64) -> UInt64 {
        var z = input &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
