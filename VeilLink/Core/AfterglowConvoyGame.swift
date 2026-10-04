import Foundation

enum AfterglowConvoyOutcome: Equatable, Sendable {
    case running
    case arrived
    case signalLost
    case hullLost
}

struct AfterglowConvoyInput: Equatable, Sendable {
    var vertical: Double
    var shielding: Bool

    init(vertical: Double = 0, shielding: Bool = false) {
        self.vertical = min(1, max(-1, vertical))
        self.shielding = shielding
    }
}

struct AfterglowHazard: Equatable, Sendable {
    let segment: Int
    let centerY: Double
    let radius: Double
    let damage: Double
    let coldDrain: Double
    let isEmberCache: Bool
}

struct AfterglowConvoyEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case impact
        case emberRecovered
        case storyBeat(String)
        case arrived
        case signalLost
        case hullLost
    }

    let tick: Int
    let kind: Kind
}

struct AfterglowConvoySnapshot: Equatable, Sendable {
    let tick: Int
    let progress: Double
    let y: Double
    let velocityY: Double
    let hull: Double
    let beacon: Double
    let shield: Double
    let storm: Double
    let shielding: Bool
    let outcome: AfterglowConvoyOutcome
    let storyLine: String?
}

struct AfterglowConvoyState: Equatable, Sendable {
    static let fixedDelta = 1.0 / 60.0
    static let worldLength = 4_800.0
    static let minimumY = 90.0
    static let maximumY = 810.0
    static let segmentLength = 190.0

    let seed: UInt64
    private(set) var tick = 0
    private(set) var x = 0.0
    private(set) var y = 450.0
    private(set) var velocityY = 0.0
    private(set) var hull = 100.0
    private(set) var beacon = 100.0
    private(set) var shield = 100.0
    private(set) var outcome: AfterglowConvoyOutcome = .running
    private(set) var lastResolvedSegment = -1
    private(set) var lastStoryBeat = -1
    private(set) var events: [AfterglowConvoyEvent] = []

    init(seed: UInt64) {
        self.seed = seed
    }

    var progress: Double {
        min(1, max(0, x / Self.worldLength))
    }

    var isFinished: Bool { outcome != .running }

    var stormIntensity: Double {
        let a = (sin(Double(tick) * 0.009 + Double(seed % 97) * 0.031) + 1) * 0.5
        let b = (sin(Double(tick) * 0.0029 + Double(seed % 53) * 0.071) + 1) * 0.5
        let pressure = 0.12 + 0.36 * sin(progress * .pi)
        return min(1, max(0, 0.14 + a * 0.28 + b * 0.22 + pressure))
    }

    mutating func step(input: AfterglowConvoyInput) {
        guard outcome == .running else { return }
        events.removeAll(keepingCapacity: true)
        tick += 1

        let storm = stormIntensity
        x = min(Self.worldLength, x + (82 + 28 * (1 - storm)) * Self.fixedDelta)

        velocityY += input.vertical * 410 * Self.fixedDelta
        velocityY *= pow(0.965, Self.fixedDelta * 60)
        y += velocityY * Self.fixedDelta

        if y < Self.minimumY {
            y = Self.minimumY
            velocityY = abs(velocityY) * 0.28
            applyImpact(baseDamage: 8, shielding: input.shielding)
        } else if y > Self.maximumY {
            y = Self.maximumY
            velocityY = -abs(velocityY) * 0.28
            applyImpact(baseDamage: 8, shielding: input.shielding)
        }

        let shieldUse = input.shielding && shield > 0
        if shieldUse {
            shield = max(0, shield - (10 + storm * 12) * Self.fixedDelta)
        } else {
            shield = min(100, shield + (4 + (1 - storm) * 3) * Self.fixedDelta)
        }

        let ambientDrain = (0.52 + storm * 1.7) * Self.fixedDelta
        beacon = max(0, beacon - ambientDrain * (shieldUse ? 0.28 : 1))

        resolveCurrentSegment(shielding: shieldUse)
        resolveStoryBeat()
        resolveOutcome()
    }

    func hazard(for segment: Int) -> AfterglowHazard {
        var value = Self.mix(seed ^ UInt64(bitPattern: Int64(segment &* 0x45d9f3b)))
        let center = 140 + Double(value % 621)
        value = Self.mix(value)
        let radius = 32 + Double(value % 53)
        value = Self.mix(value)
        let damage = 7 + Double(value % 12)
        value = Self.mix(value)
        let cold = 2 + Double(value % 7)
        value = Self.mix(value)
        let cache = segment > 0 && segment % 5 == Int(value % 5)
        return AfterglowHazard(
            segment: segment,
            centerY: center,
            radius: radius,
            damage: damage,
            coldDrain: cold,
            isEmberCache: cache
        )
    }

    func snapshot(shielding: Bool = false) -> AfterglowConvoySnapshot {
        AfterglowConvoySnapshot(
            tick: tick,
            progress: progress,
            y: y,
            velocityY: velocityY,
            hull: hull,
            beacon: beacon,
            shield: shield,
            storm: stormIntensity,
            shielding: shielding && shield > 0,
            outcome: outcome,
            storyLine: Self.storyLines.indices.contains(lastStoryBeat) ? Self.storyLines[lastStoryBeat] : nil
        )
    }

    private mutating func resolveCurrentSegment(shielding: Bool) {
        let segment = Int(x / Self.segmentLength)
        guard segment > lastResolvedSegment else { return }
        lastResolvedSegment = segment
        guard segment > 0 else { return }

        let hazard = hazard(for: segment)
        let distance = abs(y - hazard.centerY)
        if hazard.isEmberCache && distance <= max(88, hazard.radius * 1.45) {
            beacon = min(100, beacon + 15)
            shield = min(100, shield + 12)
            events.append(.init(tick: tick, kind: .emberRecovered))
            return
        }

        if distance <= hazard.radius {
            applyImpact(baseDamage: hazard.damage, shielding: shielding)
            beacon = max(0, beacon - hazard.coldDrain * (shielding ? 0.32 : 1))
        }
    }

    private mutating func applyImpact(baseDamage: Double, shielding: Bool) {
        let scale = shielding && shield > 0 ? 0.34 : 1
        hull = max(0, hull - baseDamage * scale)
        beacon = max(0, beacon - baseDamage * 0.38 * scale)
        if shielding {
            shield = max(0, shield - baseDamage * 0.9)
        }
        events.append(.init(tick: tick, kind: .impact))
    }

    private mutating func resolveStoryBeat() {
        let thresholds = [0.08, 0.28, 0.52, 0.76, 0.94]
        guard lastStoryBeat + 1 < thresholds.count else { return }
        let next = lastStoryBeat + 1
        if progress >= thresholds[next] {
            lastStoryBeat = next
            events.append(.init(tick: tick, kind: .storyBeat(Self.storyLines[next])))
        }
    }

    private mutating func resolveOutcome() {
        if x >= Self.worldLength {
            outcome = .arrived
            events.append(.init(tick: tick, kind: .arrived))
        } else if beacon <= 0 {
            outcome = .signalLost
            events.append(.init(tick: tick, kind: .signalLost))
        } else if hull <= 0 {
            outcome = .hullLost
            events.append(.init(tick: tick, kind: .hullLost))
        }
    }

    static let storyLines = [
        "信标：我还在。别让风把我们分开。",
        "信标：旧频道里还有回声……像有人在等。",
        "信标：护盾留给你也可以。我会尽量撑住。",
        "信标：前面开始变亮了。不是闪电。",
        "信标：再往前一点。我们把这束光送回去。"
    ]

    private static func mix(_ input: UInt64) -> UInt64 {
        var z = input &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
