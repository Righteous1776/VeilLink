import Foundation

enum RhythmRunPhase: Equatable, Sendable {
    case ready
    case running
    case paused
    case finished
}

enum RhythmBeatKind: Equatable, Sendable {
    case gate
    case spinner
    case energyOrb

    var isHazard: Bool {
        self != .energyOrb
    }
}

struct RhythmBeatEvent: Equatable, Sendable, Identifiable {
    let id: Int
    let beat: Int
    let lane: Int
    let kind: RhythmBeatKind
    let arrivalTime: TimeInterval
    let speedScale: Double
}

struct RhythmLevelConfiguration: Equatable, Sendable {
    static let maximumLevel = 5
    static let laneCount = 5

    let level: Int
    let bpm: Double
    let totalBeats: Int
    let travelDuration: TimeInterval

    var beatInterval: TimeInterval { 60 / bpm }
    var completionTime: TimeInterval {
        1.2 + (Double(totalBeats - 1) * beatInterval) + 1.8
    }

    static func configuration(for rawLevel: Int) -> RhythmLevelConfiguration {
        let level = min(max(rawLevel, 1), maximumLevel)
        return RhythmLevelConfiguration(
            level: level,
            bpm: 108 + Double(level - 1) * 12,
            totalBeats: 28 + level * 8,
            travelDuration: max(1.08, 1.72 - Double(level - 1) * 0.12)
        )
    }
}

enum RhythmOutcome: Equatable, Sendable {
    case perfectDodge
    case dodge
    case energyCollected
    case energyMissed
    case collision
}

struct RhythmRunState: Equatable, Sendable {
    fileprivate(set) var phase: RhythmRunPhase = .ready
    fileprivate(set) var level = 1
    fileprivate(set) var score = 0
    fileprivate(set) var combo = 0
    fileprivate(set) var bestCombo = 0
    fileprivate(set) var shield = 3
    fileprivate(set) var overdriveCharge = 0
    fileprivate(set) var overdriveRemaining: TimeInterval = 0
    fileprivate(set) var elapsed: TimeInterval = 0

    var isOverdriveActive: Bool { overdriveRemaining > 0 }
    var scoreMultiplier: Int {
        let comboMultiplier = min(5, 1 + combo / 8)
        return isOverdriveActive ? comboMultiplier * 2 : comboMultiplier
    }
}

struct RhythmFrameStep: Equatable, Sendable {
    var spawnedEvents: [RhythmBeatEvent] = []
    var didCrossBeat = false
    var didAdvanceLevel = false
    var didFinish = false
}

/// Deterministic gameplay core. SpriteKit owns rendering and collision geometry,
/// while this value type owns timing, progression and scoring for repeatable tests.
struct RhythmRunEngine: Sendable {
    private(set) var state = RhythmRunState()
    private(set) var configuration: RhythmLevelConfiguration
    private(set) var chart: [RhythmBeatEvent]

    private let seed: UInt64
    private var nextEventIndex = 0
    private var previousBeat = -1
    private var collisionCooldown: TimeInterval = 0

    init(seed: UInt64) {
        self.seed = seed
        configuration = .configuration(for: 1)
        chart = RhythmBeatGenerator.makeChart(level: 1, seed: seed)
    }

    mutating func start() {
        guard state.phase == .ready || state.phase == .paused else { return }
        state.phase = .running
    }

    mutating func pause() {
        guard state.phase == .running else { return }
        state.phase = .paused
    }

    mutating func restart() {
        state = RhythmRunState()
        configuration = .configuration(for: 1)
        chart = RhythmBeatGenerator.makeChart(level: 1, seed: seed)
        nextEventIndex = 0
        previousBeat = -1
        collisionCooldown = 0
    }

    mutating func advance(deltaTime rawDelta: TimeInterval) -> RhythmFrameStep {
        guard state.phase == .running else { return RhythmFrameStep() }

        let delta = min(max(rawDelta, 0), 0.12)
        state.elapsed += delta
        collisionCooldown = max(0, collisionCooldown - delta)
        state.overdriveRemaining = max(0, state.overdriveRemaining - delta)

        var result = RhythmFrameStep()
        let beat = Int(floor(state.elapsed / configuration.beatInterval))
        if beat != previousBeat {
            previousBeat = beat
            result.didCrossBeat = true
        }

        let spawnHorizon = state.elapsed + configuration.travelDuration
        while nextEventIndex < chart.count, chart[nextEventIndex].arrivalTime <= spawnHorizon {
            result.spawnedEvents.append(chart[nextEventIndex])
            nextEventIndex += 1
        }

        guard state.elapsed >= configuration.completionTime else { return result }

        if state.level >= RhythmLevelConfiguration.maximumLevel {
            state.phase = .finished
            result.didFinish = true
            return result
        }

        state.score += state.level * 500
        state.level += 1
        state.elapsed = 0
        configuration = .configuration(for: state.level)
        chart = RhythmBeatGenerator.makeChart(level: state.level, seed: seed)
        nextEventIndex = 0
        previousBeat = -1
        result.didAdvanceLevel = true
        return result
    }

    /// Returns false when a collision is ignored during the brief recovery window.
    @discardableResult
    mutating func register(_ outcome: RhythmOutcome) -> Bool {
        guard state.phase == .running else { return false }

        switch outcome {
        case .perfectDodge:
            reward(base: 140, charge: 13, comboIncrement: 2)
        case .dodge:
            reward(base: 80, charge: 7, comboIncrement: 1)
        case .energyCollected:
            reward(base: 190, charge: 24, comboIncrement: 1)
        case .energyMissed:
            state.combo = max(0, state.combo - 1)
        case .collision:
            guard collisionCooldown == 0, !state.isOverdriveActive else { return false }
            collisionCooldown = 0.85
            state.shield = max(0, state.shield - 1)
            state.combo = 0
            if state.shield == 0 {
                state.phase = .finished
            }
        }
        return true
    }

    @discardableResult
    mutating func activateOverdrive() -> Bool {
        guard state.phase == .running,
              state.overdriveCharge >= 100,
              !state.isOverdriveActive else { return false }
        state.overdriveCharge = 0
        state.overdriveRemaining = 4.5
        return true
    }

    private mutating func reward(base: Int, charge: Int, comboIncrement: Int) {
        state.combo += comboIncrement
        state.bestCombo = max(state.bestCombo, state.combo)
        state.score += base * state.scoreMultiplier
        state.overdriveCharge = min(100, state.overdriveCharge + charge)
    }
}

enum RhythmBeatGenerator {
    static func makeChart(level rawLevel: Int, seed: UInt64) -> [RhythmBeatEvent] {
        let configuration = RhythmLevelConfiguration.configuration(for: rawLevel)
        var random = RhythmSeededRandom(seed: mixed(seed: seed, level: configuration.level))
        var events: [RhythmBeatEvent] = []
        var previousHazardLane = -1
        var repeatedLaneCount = 0

        for beat in 0..<configuration.totalBeats {
            let primaryLane = random.nextInt(upperBound: RhythmLevelConfiguration.laneCount)
            let roll = random.nextInt(upperBound: 100)
            let kind: RhythmBeatKind
            if beat > 3, beat % 8 == 4 {
                kind = .energyOrb
            } else if configuration.level >= 2, roll < 24 {
                kind = .spinner
            } else {
                kind = .gate
            }

            var lane = primaryLane
            if kind.isHazard {
                if lane == previousHazardLane {
                    repeatedLaneCount += 1
                    if repeatedLaneCount >= 3 {
                        lane = (lane + 1 + random.nextInt(upperBound: 3)) % RhythmLevelConfiguration.laneCount
                        repeatedLaneCount = 0
                    }
                } else {
                    repeatedLaneCount = 0
                }
                previousHazardLane = lane
            }

            events.append(RhythmBeatEvent(
                id: configuration.level * 10_000 + beat * 10,
                beat: beat,
                lane: lane,
                kind: kind,
                arrivalTime: 1.2 + Double(beat) * configuration.beatInterval,
                speedScale: 1 + Double(configuration.level - 1) * 0.09
            ))

            // Later levels add syncopated hazards. They never cover every lane,
            // keeping each generated beat physically avoidable.
            if configuration.level >= 3,
               beat > 5,
               beat % max(3, 6 - configuration.level) == 0,
               kind.isHazard {
                var secondLane = random.nextInt(upperBound: RhythmLevelConfiguration.laneCount)
                if secondLane == lane {
                    secondLane = (secondLane + 2) % RhythmLevelConfiguration.laneCount
                }
                events.append(RhythmBeatEvent(
                    id: configuration.level * 10_000 + beat * 10 + 1,
                    beat: beat,
                    lane: secondLane,
                    kind: .gate,
                    arrivalTime: 1.2 + Double(beat) * configuration.beatInterval + configuration.beatInterval * 0.5,
                    speedScale: 1 + Double(configuration.level - 1) * 0.09
                ))
            }
        }

        return events.sorted {
            if $0.arrivalTime == $1.arrivalTime { return $0.id < $1.id }
            return $0.arrivalTime < $1.arrivalTime
        }
    }

    private static func mixed(seed: UInt64, level: Int) -> UInt64 {
        var value = seed &+ UInt64(level) &* 0x9E37_79B9_7F4A_7C15
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

private struct RhythmSeededRandom: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xA11C_E5EED : seed
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Int(state % UInt64(upperBound))
    }
}
