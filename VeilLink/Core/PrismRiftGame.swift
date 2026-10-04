import Foundation

enum PrismRiftOutcome: Equatable, Sendable {
    case running
    case escaped
    case destroyed
}

struct PrismRiftInput: Equatable, Sendable {
    let horizontal: Double
    let vertical: Double
    let firing: Bool
    let boosting: Bool

    init(horizontal: Double = 0, vertical: Double = 0, firing: Bool = false, boosting: Bool = false) {
        self.horizontal = min(1, max(-1, horizontal))
        self.vertical = min(1, max(-1, vertical))
        self.firing = firing
        self.boosting = boosting
    }
}

enum PrismRiftEncounterKind: Equatable, Sendable {
    case asteroid
    case mine
    case drone
    case energy
    case repair
}

struct PrismRiftEncounter: Equatable, Sendable, Identifiable {
    let segment: Int
    let kind: PrismRiftEncounterKind
    let x: Double
    let y: Double
    let radius: Double
    let severity: Double

    var id: Int { segment }
}

enum PrismRiftEventKind: Equatable, Sendable {
    case impact
    case collected(PrismRiftEncounterKind)
    case shot
    case bossArrived(Int)
    case bossHit
    case bossDefeated(Int)
    case escaped
    case destroyed
}

struct PrismRiftEvent: Equatable, Sendable {
    let tick: Int
    let kind: PrismRiftEventKind
}

struct PrismRiftSnapshot: Equatable, Sendable {
    let tick: Int
    let progress: Double
    let x: Double
    let y: Double
    let hull: Double
    let shield: Double
    let energy: Double
    let score: Int
    let combo: Int
    let wave: Int
    let bossIndex: Int?
    let bossHealth: Double?
    let outcome: PrismRiftOutcome
}

struct PrismRiftState: Equatable, Sendable {
    static let fixedDelta = 1.0 / 60.0
    static let segmentLength = 92.0
    static let finalSegment = 60
    static let bossSegments = [15, 35, 55]

    let seed: UInt64
    private(set) var tick = 0
    private(set) var distance = 0.0
    private(set) var x = 0.0
    private(set) var y = 0.0
    private(set) var velocityX = 0.0
    private(set) var velocityY = 0.0
    private(set) var hull = 100.0
    private(set) var shield = 100.0
    private(set) var energy = 100.0
    private(set) var score = 0
    private(set) var combo = 0
    private(set) var wave = 1
    private(set) var bossIndex: Int?
    private(set) var bossHealth: Double?
    private(set) var lastResolvedSegment = -1
    private(set) var outcome: PrismRiftOutcome = .running
    private(set) var events: [PrismRiftEvent] = []

    init(seed: UInt64) {
        self.seed = seed
    }

    var segment: Int { Int(distance / Self.segmentLength) }
    var progress: Double {
        min(1, max(0, distance / (Double(Self.finalSegment) * Self.segmentLength)))
    }

    var snapshot: PrismRiftSnapshot {
        PrismRiftSnapshot(
            tick: tick,
            progress: progress,
            x: x,
            y: y,
            hull: hull,
            shield: shield,
            energy: energy,
            score: score,
            combo: combo,
            wave: wave,
            bossIndex: bossIndex,
            bossHealth: bossHealth,
            outcome: outcome
        )
    }

    mutating func step(input: PrismRiftInput) {
        guard outcome == .running else { return }
        events.removeAll(keepingCapacity: true)
        tick += 1

        velocityX = (velocityX + input.horizontal * 2.8 * Self.fixedDelta) * 0.91
        velocityY = (velocityY + input.vertical * 2.8 * Self.fixedDelta) * 0.91
        x = min(1, max(-1, x + velocityX))
        y = min(1, max(-1, y + velocityY))

        if input.boosting, energy > 0, bossIndex == nil {
            distance += 178 * Self.fixedDelta
            energy = max(0, energy - 15 * Self.fixedDelta)
        } else if bossIndex == nil {
            distance += 112 * Self.fixedDelta
            energy = min(100, energy + 5.2 * Self.fixedDelta)
        } else {
            energy = min(100, energy + 7.5 * Self.fixedDelta)
        }
        shield = min(100, shield + 3.6 * Self.fixedDelta)

        enterBossIfNeeded()
        if let activeBoss = bossIndex {
            resolveBoss(activeBoss, input: input)
        } else {
            resolveSegments()
        }
        resolveOutcome()
    }

    func encounter(for segment: Int) -> PrismRiftEncounter {
        var value = Self.mix(seed ^ UInt64(bitPattern: Int64(segment &* 0x45D9F3B)))
        let x = Double(Int(value % 181) - 90) / 100
        value = Self.mix(value)
        let y = Double(Int(value % 181) - 90) / 100
        value = Self.mix(value)
        let selector = Int(value % 100)
        let kind: PrismRiftEncounterKind
        switch selector {
        case 0..<12: kind = .energy
        case 12..<18: kind = .repair
        case 18..<48: kind = .asteroid
        case 48..<73: kind = .mine
        default: kind = .drone
        }
        value = Self.mix(value)
        return PrismRiftEncounter(
            segment: segment,
            kind: kind,
            x: x,
            y: y,
            radius: kind == .asteroid ? 0.31 : (kind == .mine ? 0.23 : 0.20),
            severity: 8 + Double(value % 13)
        )
    }

    func bossPosition(index: Int, tick: Int? = nil) -> (x: Double, y: Double) {
        let time = Double(tick ?? self.tick) * Self.fixedDelta
        let phase = Double(index) * 1.37 + Double(seed % 31) * 0.03
        return (
            sin(time * (0.72 + Double(index) * 0.08) + phase) * 0.72,
            cos(time * (0.53 + Double(index) * 0.06) + phase) * 0.52
        )
    }

    private mutating func enterBossIfNeeded() {
        guard bossIndex == nil else { return }
        for (index, threshold) in Self.bossSegments.enumerated() where segment >= threshold && wave == index + 1 {
            bossIndex = index
            bossHealth = 100 + Double(index) * 42
            events.append(.init(tick: tick, kind: .bossArrived(index)))
            return
        }
    }

    private mutating func resolveBoss(_ index: Int, input: PrismRiftInput) {
        let boss = bossPosition(index: index)
        let alignment = hypot(x - boss.x, y - boss.y)
        if input.firing, energy >= 0.18 {
            energy = max(0, energy - 11 * Self.fixedDelta)
            if tick.isMultiple(of: 4) { events.append(.init(tick: tick, kind: .shot)) }
            if alignment < 0.38 {
                bossHealth = max(0, (bossHealth ?? 0) - (16 + Double(combo) * 0.25) * Self.fixedDelta)
                if tick.isMultiple(of: 5) { events.append(.init(tick: tick, kind: .bossHit)) }
            }
        }

        let attackPeriod = max(42, 88 - index * 12)
        if tick.isMultiple(of: attackPeriod), alignment < 0.48 {
            applyDamage(12 + Double(index) * 4)
        }
        guard (bossHealth ?? 0) <= 0 else { return }
        score += 2_500 * (index + 1)
        combo += 5
        events.append(.init(tick: tick, kind: .bossDefeated(index)))
        bossIndex = nil
        bossHealth = nil
        wave = index + 2
        distance += Self.segmentLength
        lastResolvedSegment = segment
    }

    private mutating func resolveSegments() {
        let current = segment
        guard current > lastResolvedSegment else { return }
        let first = max(0, lastResolvedSegment + 1)
        for index in first...current {
            lastResolvedSegment = index
            guard index > 0, !Self.bossSegments.contains(index) else { continue }
            let encounter = encounter(for: index)
            let separation = hypot(x - encounter.x, y - encounter.y)
            guard separation <= encounter.radius else {
                if encounter.kind == .drone, separation < 0.48 { score += 45; combo += 1 }
                continue
            }
            switch encounter.kind {
            case .energy:
                energy = min(100, energy + 28)
                score += 180
                combo += 1
                events.append(.init(tick: tick, kind: .collected(.energy)))
            case .repair:
                hull = min(100, hull + 18)
                shield = min(100, shield + 24)
                score += 220
                combo += 1
                events.append(.init(tick: tick, kind: .collected(.repair)))
            case .asteroid, .mine, .drone:
                applyDamage(encounter.severity)
            }
        }
    }

    private mutating func applyDamage(_ amount: Double) {
        let absorbed = min(shield, amount * 0.78)
        shield -= absorbed
        hull = max(0, hull - max(0, amount - absorbed))
        combo = 0
        events.append(.init(tick: tick, kind: .impact))
    }

    private mutating func resolveOutcome() {
        if hull <= 0 {
            outcome = .destroyed
            events.append(.init(tick: tick, kind: .destroyed))
        } else if segment >= Self.finalSegment, bossIndex == nil, wave > Self.bossSegments.count {
            outcome = .escaped
            score += 10_000 + Int(hull + shield + energy) * 10
            events.append(.init(tick: tick, kind: .escaped))
        }
    }

    private static func mix(_ input: UInt64) -> UInt64 {
        var z = input &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
