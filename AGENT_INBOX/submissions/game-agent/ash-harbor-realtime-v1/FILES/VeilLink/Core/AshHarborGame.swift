import Foundation

enum AshHarborOutcome: Equatable, Sendable {
    case running
    case reachedHarbor
    case hullLost
    case timeExpired
}

struct AshHarborInput: Equatable, Sendable {
    var throttle: Double
    var rudder: Double
    var rescuing: Bool
    var searchlight: Bool

    init(throttle: Double = 0.55, rudder: Double = 0, rescuing: Bool = false, searchlight: Bool = true) {
        self.throttle = min(1, max(0, throttle))
        self.rudder = min(1, max(-1, rudder))
        self.rescuing = rescuing
        self.searchlight = searchlight
    }
}

struct AshHarborRescueSite: Equatable, Sendable {
    let id: Int
    let x: Double
    let y: Double
    let holdTicks: Int
    let radioLine: String
}

struct AshHarborDebris: Equatable, Sendable {
    let id: Int
    let x: Double
    let y: Double
    let radius: Double
    let damage: Double
}

struct AshHarborLevel: Equatable, Sendable {
    let name: String
    let worldLength: Double
    let timeLimitTicks: Int
    let rescueSites: [AshHarborRescueSite]
    let debris: [AshHarborDebris]

    static let prologue = AshHarborLevel(
        name: "灰港 · 01 / 灯塔线",
        worldLength: 5_200,
        timeLimitTicks: 60 * 150,
        rescueSites: [
            .init(id: 1, x: 920, y: 330, holdTicks: 86, radioLine: "旧七码头：看到你了。别靠太快。"),
            .init(id: 2, x: 2_060, y: 610, holdTicks: 104, radioLine: "仓库屋顶：灯还亮着，我们在这里。"),
            .init(id: 3, x: 3_360, y: 260, holdTicks: 118, radioLine: "防波堤：浪太高了……再靠近一点。"),
            .init(id: 4, x: 4_420, y: 520, holdTicks: 132, radioLine: "灯塔脚下：最后一组信号。"),
        ],
        debris: [
            .init(id: 101, x: 560, y: 520, radius: 44, damage: 11),
            .init(id: 102, x: 1_430, y: 245, radius: 52, damage: 14),
            .init(id: 103, x: 2_640, y: 470, radius: 58, damage: 16),
            .init(id: 104, x: 3_780, y: 650, radius: 48, damage: 13),
            .init(id: 105, x: 4_760, y: 305, radius: 62, damage: 18),
        ]
    )
}

struct AshHarborEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case impact(Int)
        case rescueStarted(Int)
        case rescueCompleted(Int, String)
        case radio(String)
        case reachedHarbor
        case hullLost
        case timeExpired
    }

    let tick: Int
    let kind: Kind
}

struct AshHarborSnapshot: Equatable, Sendable {
    let tick: Int
    let x: Double
    let y: Double
    let speed: Double
    let hull: Double
    let battery: Double
    let storm: Double
    let rescued: Int
    let totalRescues: Int
    let rescueProgress: Double
    let activeRescueID: Int?
    let timeRemaining: Double
    let outcome: AshHarborOutcome
}

struct AshHarborState: Equatable, Sendable {
    static let fixedDelta = 1.0 / 60.0
    static let minimumY = 110.0
    static let maximumY = 730.0

    let seed: UInt64
    let level: AshHarborLevel

    private(set) var tick = 0
    private(set) var x = 80.0
    private(set) var y = 430.0
    private(set) var velocityX = 0.0
    private(set) var velocityY = 0.0
    private(set) var hull = 100.0
    private(set) var battery = 100.0
    private(set) var outcome: AshHarborOutcome = .running
    private(set) var rescuedSiteIDs: Set<Int> = []
    private(set) var resolvedDebrisIDs: Set<Int> = []
    private(set) var activeRescueID: Int?
    private(set) var activeRescueTicks = 0
    private(set) var events: [AshHarborEvent] = []

    init(seed: UInt64, level: AshHarborLevel = .prologue) {
        self.seed = seed
        self.level = level
    }

    var isFinished: Bool { outcome != .running }
    var progress: Double { min(1, max(0, x / level.worldLength)) }

    var stormIntensity: Double {
        let s1 = (sin(Double(tick) * 0.008 + Double(seed % 89) * 0.031) + 1) * 0.5
        let s2 = (sin(Double(tick) * 0.0027 + Double(seed % 47) * 0.091) + 1) * 0.5
        return min(1, max(0, 0.24 + s1 * 0.36 + s2 * 0.28))
    }

    mutating func step(input: AshHarborInput) {
        guard outcome == .running else { return }
        events.removeAll(keepingCapacity: true)
        tick += 1

        let storm = stormIntensity
        let targetSpeed = 34 + input.throttle * 92
        velocityX += (targetSpeed - velocityX) * 0.028
        x += velocityX * Self.fixedDelta

        let wavePush = sin(Double(tick) * 0.071 + Double(seed % 31)) * (18 + 34 * storm)
        velocityY += (input.rudder * 330 + wavePush * 0.42) * Self.fixedDelta
        velocityY *= pow(0.955, Self.fixedDelta * 60)
        y += velocityY * Self.fixedDelta

        if y < Self.minimumY {
            y = Self.minimumY
            velocityY = abs(velocityY) * 0.18
            applyImpact(damage: 8, id: -1)
        } else if y > Self.maximumY {
            y = Self.maximumY
            velocityY = -abs(velocityY) * 0.18
            applyImpact(damage: 8, id: -2)
        }

        if input.searchlight && battery > 0 {
            battery = max(0, battery - (2.8 + storm * 1.8) * Self.fixedDelta)
        } else {
            battery = min(100, battery + (1.25 + (1 - storm) * 0.9) * Self.fixedDelta)
        }

        resolveDebris()
        resolveRescue(input: input)
        resolveOutcome()
    }

    func snapshot() -> AshHarborSnapshot {
        let total = max(1, level.rescueSites.count)
        let site = activeRescueID.flatMap { id in level.rescueSites.first(where: { $0.id == id }) }
        let rescueFraction = site.map { min(1, Double(activeRescueTicks) / Double(max(1, $0.holdTicks))) } ?? 0
        return AshHarborSnapshot(
            tick: tick,
            x: x,
            y: y,
            speed: velocityX,
            hull: hull,
            battery: battery,
            storm: stormIntensity,
            rescued: rescuedSiteIDs.count,
            totalRescues: total,
            rescueProgress: rescueFraction,
            activeRescueID: activeRescueID,
            timeRemaining: max(0, Double(level.timeLimitTicks - tick) * Self.fixedDelta),
            outcome: outcome
        )
    }

    private mutating func resolveDebris() {
        for debris in level.debris where !resolvedDebrisIDs.contains(debris.id) {
            guard abs(debris.x - x) <= max(10, velocityX * Self.fixedDelta + 10) else { continue }
            if abs(debris.y - y) <= debris.radius {
                resolvedDebrisIDs.insert(debris.id)
                applyImpact(damage: debris.damage, id: debris.id)
            }
        }
    }

    private mutating func resolveRescue(input: AshHarborInput) {
        let nearby = level.rescueSites
            .filter { !rescuedSiteIDs.contains($0.id) }
            .filter { abs($0.x - x) <= 95 && abs($0.y - y) <= 105 }
            .min { abs($0.x - x) < abs($1.x - x) }

        guard let site = nearby, input.rescuing, velocityX <= 62 else {
            activeRescueID = nil
            activeRescueTicks = 0
            return
        }

        if activeRescueID != site.id {
            activeRescueID = site.id
            activeRescueTicks = 0
            events.append(.init(tick: tick, kind: .rescueStarted(site.id)))
        }

        activeRescueTicks += 1
        if activeRescueTicks >= site.holdTicks {
            rescuedSiteIDs.insert(site.id)
            activeRescueID = nil
            activeRescueTicks = 0
            battery = min(100, battery + 6)
            events.append(.init(tick: tick, kind: .rescueCompleted(site.id, site.radioLine)))
            events.append(.init(tick: tick, kind: .radio(site.radioLine)))
        }
    }

    private mutating func applyImpact(damage: Double, id: Int) {
        hull = max(0, hull - damage)
        events.append(.init(tick: tick, kind: .impact(id)))
    }

    private mutating func resolveOutcome() {
        if x >= level.worldLength {
            outcome = .reachedHarbor
            events.append(.init(tick: tick, kind: .reachedHarbor))
        } else if hull <= 0 {
            outcome = .hullLost
            events.append(.init(tick: tick, kind: .hullLost))
        } else if tick >= level.timeLimitTicks {
            outcome = .timeExpired
            events.append(.init(tick: tick, kind: .timeExpired))
        }
    }
}
