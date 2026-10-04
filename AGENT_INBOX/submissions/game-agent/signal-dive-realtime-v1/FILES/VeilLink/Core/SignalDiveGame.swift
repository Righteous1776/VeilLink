import Foundation

enum SignalDiveOutcome: Equatable, Sendable {
    case running
    case surfaced
    case hullFailure
    case powerLoss
}

struct SignalDiveInput: Equatable, Sendable {
    var thrustX: Double
    var thrustY: Double
    var sonarPulse: Bool
    var floodlight: Bool

    init(
        thrustX: Double = 0,
        thrustY: Double = 0,
        sonarPulse: Bool = false,
        floodlight: Bool = true
    ) {
        self.thrustX = min(1, max(-1, thrustX))
        self.thrustY = min(1, max(-1, thrustY))
        self.sonarPulse = sonarPulse
        self.floodlight = floodlight
    }
}

struct SignalDiveBeacon: Equatable, Sendable {
    let id: Int
    let x: Double
    let depth: Double
    let captureRadius: Double
    let line: String
}

struct SignalDiveObstacle: Equatable, Sendable {
    let id: Int
    let x: Double
    let depth: Double
    let radius: Double
    let damage: Double
}

struct SignalDiveContact: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case terrain
        case beacon(Int)
        case biological(Int)
        case massiveUnknown(Int)
    }

    let kind: Kind
    let distance: Double
    let bearing: Double
}

struct SignalDiveEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case sonar([SignalDiveContact])
        case beaconRecovered(Int, String)
        case impact(Int)
        case radio(String)
        case surfaced
        case hullFailure
        case powerLoss
    }

    let tick: Int
    let kind: Kind
}

struct SignalDiveSnapshot: Equatable, Sendable {
    let tick: Int
    let x: Double
    let depth: Double
    let velocityX: Double
    let velocityY: Double
    let hull: Double
    let power: Double
    let pressure: Double
    let noise: Double
    let recovered: Int
    let totalBeacons: Int
    let sonarCooldown: Double
    let outcome: SignalDiveOutcome
    let lastLine: String?
}

struct SignalDiveLevel: Equatable, Sendable {
    let length: Double
    let maxDepth: Double
    let beacons: [SignalDiveBeacon]
    let obstacles: [SignalDiveObstacle]

    static let trenchOne = SignalDiveLevel(
        length: 6_600,
        maxDepth: 1_400,
        beacons: [
            .init(
                id: 1,
                x: 1_120,
                depth: 420,
                captureRadius: 82,
                line: "信标一号：这里还有回声。"
            ),
            .init(
                id: 2,
                x: 2_520,
                depth: 760,
                captureRadius: 88,
                line: "信标二号：下面比地图上更深。"
            ),
            .init(
                id: 3,
                x: 4_160,
                depth: 1_020,
                captureRadius: 92,
                line: "信标三号：收到你了。别关灯。"
            ),
            .init(
                id: 4,
                x: 5_740,
                depth: 1_220,
                captureRadius: 96,
                line: "信标四号：最后一个坐标。上面还有人在等。"
            )
        ],
        obstacles: [
            .init(id: 201, x: 730, depth: 370, radius: 72, damage: 9),
            .init(id: 202, x: 1_760, depth: 640, radius: 96, damage: 13),
            .init(id: 203, x: 3_180, depth: 890, radius: 112, damage: 15),
            .init(id: 204, x: 4_920, depth: 1_120, radius: 102, damage: 14),
            .init(id: 205, x: 6_040, depth: 1_270, radius: 128, damage: 18)
        ]
    )
}

struct SignalDiveState: Equatable, Sendable {
    static let fixedDelta = 1.0 / 60.0
    static let minimumDepth = 80.0

    let seed: UInt64
    let level: SignalDiveLevel

    private(set) var tick = 0
    private(set) var x = 120.0
    private(set) var depth = 260.0
    private(set) var velocityX = 0.0
    private(set) var velocityY = 0.0
    private(set) var hull = 100.0
    private(set) var power = 100.0
    private(set) var noise = 0.0
    private(set) var sonarCooldownTicks = 0
    private(set) var recoveredBeaconIDs: Set<Int> = []
    private(set) var resolvedObstacleIDs: Set<Int> = []
    private(set) var events: [SignalDiveEvent] = []
    private(set) var lastLine: String?
    private(set) var outcome: SignalDiveOutcome = .running
    private(set) var divePhase = true

    init(seed: UInt64, level: SignalDiveLevel = .trenchOne) {
        self.seed = seed
        self.level = level
    }

    var isFinished: Bool {
        outcome != .running
    }

    var pressure: Double {
        min(1.35, depth / level.maxDepth * 1.15)
    }

    mutating func step(input: SignalDiveInput) {
        guard outcome == .running else { return }

        tick += 1
        events.removeAll(keepingCapacity: true)

        if sonarCooldownTicks > 0 {
            sonarCooldownTicks -= 1
        }

        let pressureFactor = pressure
        let thrustScale = max(0.42, 1.0 - pressureFactor * 0.22)

        velocityX += input.thrustX * 54 * thrustScale * Self.fixedDelta
        velocityY += input.thrustY * 46 * thrustScale * Self.fixedDelta
        velocityX *= pow(0.977, Self.fixedDelta * 60)
        velocityY *= pow(0.972, Self.fixedDelta * 60)

        x += velocityX * Self.fixedDelta
        depth += velocityY * Self.fixedDelta
        x = min(level.length, max(0, x))

        if depth < Self.minimumDepth {
            depth = Self.minimumDepth
            velocityY = abs(velocityY) * 0.22
        } else if depth > level.maxDepth {
            depth = level.maxDepth
            velocityY = -abs(velocityY) * 0.22
            applyImpact(
                id: -1,
                damage: 8 + pressureFactor * 4
            )
        }

        let motionDrain =
            (abs(input.thrustX) + abs(input.thrustY)) * 0.28
        let lampDrain = input.floodlight ? 0.20 : 0

        power = max(
            0,
            power -
                (
                    0.05 +
                    motionDrain +
                    lampDrain +
                    pressureFactor * 0.09
                ) * Self.fixedDelta
        )

        noise = max(
            0,
            min(
                1,
                noise +
                    (
                        (abs(input.thrustX) + abs(input.thrustY)) * 0.014 -
                        0.006
                    ) * Self.fixedDelta * 60
            )
        )

        if input.sonarPulse,
           sonarCooldownTicks == 0,
           power >= 1.8 {
            power = max(0, power - 1.8)
            noise = min(1, noise + 0.18)
            sonarCooldownTicks = 90
            events.append(
                .init(
                    tick: tick,
                    kind: .sonar(sonarContacts())
                )
            )
        }

        resolveObstacleCollisions()
        resolveBeaconRecovery()
        updateMissionPhase()
        resolveOutcome()
    }

    func snapshot() -> SignalDiveSnapshot {
        SignalDiveSnapshot(
            tick: tick,
            x: x,
            depth: depth,
            velocityX: velocityX,
            velocityY: velocityY,
            hull: hull,
            power: power,
            pressure: pressure,
            noise: noise,
            recovered: recoveredBeaconIDs.count,
            totalBeacons: level.beacons.count,
            sonarCooldown:
                Double(sonarCooldownTicks) * Self.fixedDelta,
            outcome: outcome,
            lastLine: lastLine
        )
    }

    func sonarContacts(
        maxRange: Double = 760
    ) -> [SignalDiveContact] {
        var contacts: [SignalDiveContact] = []

        for beacon in level.beacons
        where !recoveredBeaconIDs.contains(beacon.id) {
            let dx = beacon.x - x
            let dy = beacon.depth - depth
            let distance = hypot(dx, dy)

            if distance <= maxRange {
                contacts.append(
                    .init(
                        kind: .beacon(beacon.id),
                        distance: distance,
                        bearing: atan2(dy, dx)
                    )
                )
            }
        }

        for obstacle in level.obstacles {
            let dx = obstacle.x - x
            let dy = obstacle.depth - depth
            let distance = hypot(dx, dy)

            if distance <= maxRange * 0.78 {
                contacts.append(
                    .init(
                        kind: .terrain,
                        distance: distance,
                        bearing: atan2(dy, dx)
                    )
                )
            }
        }

        contacts.append(
            contentsOf: biologicalContacts(
                maxRange: maxRange
            )
        )

        contacts.append(
            contentsOf: massiveUnknownContacts(
                maxRange: maxRange
            )
        )

        return contacts.sorted { lhs, rhs in
            if lhs.distance == rhs.distance {
                return lhs.bearing < rhs.bearing
            }
            return lhs.distance < rhs.distance
        }
    }

    private func biologicalContacts(
        maxRange: Double
    ) -> [SignalDiveContact] {
        let segment = Int(x / 620)
        var output: [SignalDiveContact] = []

        for offset in -1...2 {
            let candidate = segment + offset
            guard candidate >= 0 else { continue }

            let anchorX =
                Double(candidate) * 620 +
                160 +
                deterministicUnit(
                    salt: UInt64(candidate) ^ 0xF157
                ) * 210

            let depthBand =
                260 +
                deterministicUnit(
                    salt: UInt64(candidate) ^ 0xB10
                ) * 930

            let dx = anchorX - x
            let dy = depthBand - depth
            let distance = hypot(dx, dy)

            if distance <= maxRange * 0.88 {
                output.append(
                    .init(
                        kind: .biological(candidate),
                        distance: distance,
                        bearing: atan2(dy, dx)
                    )
                )
            }
        }

        return output
    }

    private func massiveUnknownContacts(
        maxRange: Double
    ) -> [SignalDiveContact] {
        let segment = Int(x / 900)
        var output: [SignalDiveContact] = []

        for offset in -1...1 {
            let candidate = segment + offset
            guard candidate >= 1 else { continue }

            let anchorX = Double(candidate) * 900 + 280
            let anchorDepth =
                680 +
                deterministicUnit(
                    salt: UInt64(candidate) ^ 0xD33F
                ) * 610

            let dx = anchorX - x
            let dy = anchorDepth - depth
            let distance = hypot(dx, dy)

            if distance <= maxRange * 1.25 {
                output.append(
                    .init(
                        kind: .massiveUnknown(candidate),
                        distance: distance,
                        bearing: atan2(dy, dx)
                    )
                )
            }
        }

        return output
    }

    private mutating func resolveObstacleCollisions() {
        for obstacle in level.obstacles
        where !resolvedObstacleIDs.contains(obstacle.id) {
            let dx = obstacle.x - x
            let dy = obstacle.depth - depth
            let distance = hypot(dx, dy)

            if distance <= obstacle.radius {
                resolvedObstacleIDs.insert(obstacle.id)
                applyImpact(
                    id: obstacle.id,
                    damage:
                        obstacle.damage +
                        pressure * 4
                )
            }
        }
    }

    private mutating func resolveBeaconRecovery() {
        for beacon in level.beacons
        where !recoveredBeaconIDs.contains(beacon.id) {
            let distance = hypot(
                beacon.x - x,
                beacon.depth - depth
            )

            if distance <= beacon.captureRadius,
               abs(velocityX) < 18,
               abs(velocityY) < 18 {
                recoveredBeaconIDs.insert(beacon.id)
                power = min(100, power + 8)
                lastLine = beacon.line

                events.append(
                    .init(
                        tick: tick,
                        kind: .beaconRecovered(
                            beacon.id,
                            beacon.line
                        )
                    )
                )

                events.append(
                    .init(
                        tick: tick,
                        kind: .radio(beacon.line)
                    )
                )
            }
        }
    }

    private mutating func updateMissionPhase() {
        if divePhase,
           recoveredBeaconIDs.count == level.beacons.count {
            divePhase = false
            lastLine =
                "控制台：四个信标都在。现在把它们带回有光的地方。"

            if let lastLine {
                events.append(
                    .init(
                        tick: tick,
                        kind: .radio(lastLine)
                    )
                )
            }
        }
    }

    private mutating func applyImpact(
        id: Int,
        damage: Double
    ) {
        hull = max(0, hull - damage)
        noise = min(1, noise + 0.12)

        events.append(
            .init(
                tick: tick,
                kind: .impact(id)
            )
        )
    }

    private mutating func resolveOutcome() {
        if hull <= 0 {
            outcome = .hullFailure
            lastLine =
                "控制台：艇体失压。航迹最后深度已记录。"
            events.append(
                .init(
                    tick: tick,
                    kind: .hullFailure
                )
            )
        } else if power <= 0 {
            outcome = .powerLoss
            lastLine =
                "控制台：主电池离线。深海里只剩被动仪表。"
            events.append(
                .init(
                    tick: tick,
                    kind: .powerLoss
                )
            )
        } else if !divePhase,
                  depth <= 120,
                  x >= level.length * 0.82 {
            outcome = .surfaced
            lastLine =
                recoveredBeaconIDs.count == level.beacons.count
                ? "水面台：四个信号都回来了。欢迎回来。"
                : "水面台：收到你的艇。"

            events.append(
                .init(
                    tick: tick,
                    kind: .surfaced
                )
            )
        }
    }

    private func deterministicUnit(
        salt: UInt64
    ) -> Double {
        Double(mix(seed ^ salt) & 0xFFFF) /
            Double(0xFFFF)
    }

    private func mix(_ input: UInt64) -> UInt64 {
        var z = input &+ 0x9E3779B97F4A7C15
        z =
            (z ^ (z >> 30)) &*
            0xBF58476D1CE4E5B9
        z =
            (z ^ (z >> 27)) &*
            0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
