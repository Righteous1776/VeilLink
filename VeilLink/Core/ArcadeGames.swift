import Foundation

// MARK: - Arc artillery

struct ArtilleryShot: Equatable, Sendable {
    let angle: Int
    let power: Int
    let wind: Int
    let landingX: Double
    let landingY: Double
    let damage: Int
}

struct ArtilleryState: Equatable, Sendable {
    static let worldWidth = 1_000.0
    static let worldHeight = 520.0
    static let maximumTurns = 24

    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var hostHealth = 5
    private(set) var guestHealth = 5
    private(set) var turn = 0
    private(set) var winner: MiniGamePlayer?
    private(set) var lastShot: ArtilleryShot?

    var isDraw: Bool {
        turn >= Self.maximumTurns && winner == nil && hostHealth == guestHealth
    }

    func health(for player: MiniGamePlayer) -> Int {
        player == .host ? hostHealth : guestHealth
    }

    static func turretX(for player: MiniGamePlayer) -> Double {
        player == .host ? 110 : 890
    }

    static func terrainHeight(at x: Double) -> Double {
        let clamped = min(Self.worldWidth, max(0, x))
        let broadHill = 42 * sin((clamped / Self.worldWidth) * .pi)
        let ridge = 19 * sin((clamped / Self.worldWidth) * .pi * 3.2 + 0.45)
        return 78 + broadHill + ridge
    }

    static func wind(sessionID: String, turn: Int) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in Data("\(sessionID)|artillery|\(turn)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % 25) - 12
    }

    static func simulate(
        angle: Int,
        power: Int,
        actor: MiniGamePlayer,
        sessionID: String,
        turn: Int
    ) -> ArtilleryShot {
        let boundedAngle = min(80, max(15, angle))
        let boundedPower = min(100, max(30, power))
        let wind = wind(sessionID: sessionID, turn: turn)
        let radians = Double(boundedAngle) * .pi / 180
        let direction = actor == .host ? 1.0 : -1.0
        // 2.85 keeps the full 780-unit arena reachable around 45° without making
        // low-power calibration shots cross the whole map.
        let speed = Double(boundedPower) * 2.85
        var x = turretX(for: actor)
        var y = terrainHeight(at: x) + 24
        var vx = cos(radians) * speed * direction
        var vy = sin(radians) * speed
        let targetX = turretX(for: actor.opponent)
        var closest = hypot(x - targetX, y - (terrainHeight(at: targetX) + 18))
        let step = 0.035

        for _ in 0..<520 {
            vx += Double(wind) * 0.19 * step
            vy -= 92 * step
            x += vx * step
            y += vy * step
            closest = min(closest, hypot(x - targetX, y - (terrainHeight(at: targetX) + 18)))
            if x < 0 || x > Self.worldWidth || y > Self.worldHeight { break }
            if y <= terrainHeight(at: x) { break }
        }

        let damage: Int
        if closest <= 30 { damage = 2 }
        else if closest <= 68 { damage = 1 }
        else { damage = 0 }
        return ArtilleryShot(
            angle: boundedAngle,
            power: boundedPower,
            wind: wind,
            landingX: min(Self.worldWidth, max(0, x)),
            landingY: max(0, y),
            damage: damage
        )
    }

    @discardableResult
    mutating func apply(angle: Int, power: Int, actor: MiniGamePlayer, sessionID: String) -> Bool {
        guard winner == nil, !isDraw, actor == currentPlayer,
              (15...80).contains(angle), (30...100).contains(power) else { return false }
        let shot = Self.simulate(angle: angle, power: power, actor: actor, sessionID: sessionID, turn: turn)
        lastShot = shot
        if actor == .host { guestHealth = max(0, guestHealth - shot.damage) }
        else { hostHealth = max(0, hostHealth - shot.damage) }
        turn += 1

        if health(for: actor.opponent) == 0 {
            winner = actor
        } else if turn >= Self.maximumTurns {
            if hostHealth > guestHealth { winner = .host }
            else if guestHealth > hostHealth { winner = .guest }
        } else {
            currentPlayer = actor.opponent
        }
        return true
    }
}

enum ArtilleryBot {
    static func chooseShot(in state: ArtilleryState, actor: MiniGamePlayer, sessionID: String) -> (angle: Int, power: Int)? {
        guard state.currentPlayer == actor, state.winner == nil, !state.isDraw else { return nil }
        let targetX = ArtilleryState.turretX(for: actor.opponent)
        var best: (angle: Int, power: Int, score: Double)?
        for angle in stride(from: 18, through: 78, by: 3) {
            for power in stride(from: 34, through: 100, by: 3) {
                let shot = ArtilleryState.simulate(
                    angle: angle,
                    power: power,
                    actor: actor,
                    sessionID: sessionID,
                    turn: state.turn
                )
                let miss = abs(shot.landingX - targetX)
                let score = Double(shot.damage * 10_000) - miss - Double(power) * 0.02
                if best == nil || score > best!.score {
                    best = (angle, power, score)
                }
            }
        }
        return best.map { ($0.angle, $0.power) }
    }
}

// MARK: - Light trail runner

struct LightTrailState: Equatable, Sendable {
    static let laneCount = 5
    static let rounds = 18

    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var hostLane = 2
    private(set) var guestLane = 2
    private(set) var hostShield = 3
    private(set) var guestShield = 3
    private(set) var hostEnergy = 0
    private(set) var guestEnergy = 0
    private(set) var turn = 0
    private(set) var winner: MiniGamePlayer?
    private(set) var lastShift = 0
    private(set) var lastCollision = false
    private(set) var lastEnergyPickup = false

    var round: Int { min(Self.rounds, turn / 2) }
    var isDraw: Bool { turn >= Self.rounds * 2 && winner == nil }

    func lane(for player: MiniGamePlayer) -> Int { player == .host ? hostLane : guestLane }
    func shield(for player: MiniGamePlayer) -> Int { player == .host ? hostShield : guestShield }
    func energy(for player: MiniGamePlayer) -> Int { player == .host ? hostEnergy : guestEnergy }

    static func courseValue(sessionID: String, round: Int, salt: String) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in Data("\(sessionID)|light-trail|\(round)|\(salt)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % UInt64(laneCount))
    }

    static func obstacleLanes(sessionID: String, round: Int) -> Set<Int> {
        let first = courseValue(sessionID: sessionID, round: round, salt: "wall-a")
        var second = courseValue(sessionID: sessionID, round: round, salt: "wall-b")
        if second == first { second = (second + 2) % laneCount }
        return round % 4 == 3 ? [first, second] : [first]
    }

    static func energyLane(sessionID: String, round: Int) -> Int {
        courseValue(sessionID: sessionID, round: round, salt: "energy")
    }

    @discardableResult
    mutating func apply(shift: Int, actor: MiniGamePlayer, sessionID: String) -> Bool {
        guard winner == nil, !isDraw, actor == currentPlayer, (-1...1).contains(shift) else { return false }
        let playerRound = turn / 2
        let destination = min(Self.laneCount - 1, max(0, lane(for: actor) + shift))
        guard destination != lane(for: actor) || shift == 0 else { return false }

        lastShift = shift
        lastCollision = Self.obstacleLanes(sessionID: sessionID, round: playerRound).contains(destination)
        lastEnergyPickup = !lastCollision && Self.energyLane(sessionID: sessionID, round: playerRound) == destination
        if actor == .host {
            hostLane = destination
            if lastCollision { hostShield = max(0, hostShield - 1) }
            if lastEnergyPickup { hostEnergy += 1 }
        } else {
            guestLane = destination
            if lastCollision { guestShield = max(0, guestShield - 1) }
            if lastEnergyPickup { guestEnergy += 1 }
        }
        turn += 1

        if shield(for: actor) == 0 {
            winner = actor.opponent
        } else if turn >= Self.rounds * 2 {
            let hostScore = hostShield * 100 + hostEnergy
            let guestScore = guestShield * 100 + guestEnergy
            if hostScore > guestScore { winner = .host }
            else if guestScore > hostScore { winner = .guest }
        } else {
            currentPlayer = actor.opponent
        }
        return true
    }
}

enum LightTrailBot {
    static func chooseShift(in state: LightTrailState, actor: MiniGamePlayer, sessionID: String) -> Int? {
        guard state.currentPlayer == actor, state.winner == nil, !state.isDraw else { return nil }
        let round = state.turn / 2
        let lane = state.lane(for: actor)

        return (-1...1)
            .filter { (0..<LightTrailState.laneCount).contains(lane + $0) }
            .max { lhs, rhs in
                score(
                    lane: lane + lhs,
                    round: round,
                    sessionID: sessionID,
                    depth: 3
                ) < score(
                    lane: lane + rhs,
                    round: round,
                    sessionID: sessionID,
                    depth: 3
                )
            }
    }

    /// Three-sector deterministic look-ahead. It never bypasses the real rule
    /// gate; this only ranks the three legal lane commands before application.
    private static func score(
        lane: Int,
        round: Int,
        sessionID: String,
        depth: Int
    ) -> Int {
        guard depth > 0, round < LightTrailState.rounds else { return 0 }

        let obstacles = LightTrailState.obstacleLanes(
            sessionID: sessionID,
            round: round
        )
        let energy = LightTrailState.energyLane(
            sessionID: sessionID,
            round: round
        )

        var immediate = 0
        immediate += obstacles.contains(lane) ? -1_000 : 0
        immediate += lane == energy ? 85 : 0
        immediate -= abs(lane - 2) * 5

        guard depth > 1 else { return immediate }

        let future = (-1...1)
            .map { lane + $0 }
            .filter { (0..<LightTrailState.laneCount).contains($0) }
            .map {
                score(
                    lane: $0,
                    round: round + 1,
                    sessionID: sessionID,
                    depth: depth - 1
                )
            }
            .max() ?? 0

        return immediate + Int(Double(future) * 0.68)
    }
}
