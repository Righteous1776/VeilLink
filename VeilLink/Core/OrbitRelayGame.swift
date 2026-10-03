import Foundation

struct OrbitRelayPoint: Equatable, Sendable {
    var x: Double
    var y: Double

    func distance(to other: OrbitRelayPoint) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

struct OrbitRelayVector: Equatable, Sendable {
    var x: Double
    var y: Double

    var magnitude: Double { hypot(x, y) }
}

struct OrbitRelayMove: Equatable, Sendable {
    let angle: Int
    let power: Int
}

struct OrbitRelayCraft: Equatable, Sendable {
    var position: OrbitRelayPoint
    var velocity: OrbitRelayVector
    var fuel: Int
    var stability: Int
    var score: Int
}

struct OrbitRelayTurnResult: Equatable, Sendable {
    let actor: MiniGamePlayer
    let move: OrbitRelayMove
    let capturedRelay: Bool
    let boundaryHits: Int
    let wellWarning: Bool
    let fuelSpent: Int
    let path: [OrbitRelayPoint]
}

struct OrbitRelayState: Equatable, Sendable {
    static let fieldWidth = 1_000.0
    static let fieldHeight = 700.0
    static let center = OrbitRelayPoint(x: 500, y: 350)
    static let relayCaptureRadius = 48.0
    static let exclusionRadius = 92.0
    static let winningScore = 3
    static let maximumTurns = 24

    private static let fixedTimeStep = 0.055
    private static let simulationSteps = 320
    private static let gravityCoefficient = 185_000.0

    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var hostCraft = OrbitRelayCraft(
        position: OrbitRelayPoint(x: 220, y: 350),
        velocity: OrbitRelayVector(x: 0, y: -43),
        fuel: 100,
        stability: 5,
        score: 0
    )
    private(set) var guestCraft = OrbitRelayCraft(
        position: OrbitRelayPoint(x: 780, y: 350),
        velocity: OrbitRelayVector(x: 0, y: 43),
        fuel: 100,
        stability: 5,
        score: 0
    )
    private(set) var relayIndex = 0
    private(set) var turn = 0
    private(set) var winner: MiniGamePlayer?
    private(set) var isDraw = false
    private(set) var lastTurn: OrbitRelayTurnResult?

    var isFinished: Bool { winner != nil || isDraw }

    func craft(for player: MiniGamePlayer) -> OrbitRelayCraft {
        player == .host ? hostCraft : guestCraft
    }

    func relayPoint(sessionID: String) -> OrbitRelayPoint {
        Self.relayPoint(sessionID: sessionID, index: relayIndex)
    }

    static func relayPoint(sessionID: String, index: Int) -> OrbitRelayPoint {
        let angleHash = stableHash("\(sessionID)|orbit-relay|angle|\(index)")
        let radiusHash = stableHash("\(sessionID)|orbit-relay|radius|\(index)")
        let angle = Double(angleHash % 360) * .pi / 180
        let radius = 190.0 + Double(radiusHash % 111)
        return OrbitRelayPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    @discardableResult
    mutating func apply(
        move: OrbitRelayMove,
        actor: MiniGamePlayer,
        sessionID: String
    ) -> Bool {
        guard !isFinished,
              actor == currentPlayer,
              !sessionID.isEmpty,
              (0..<360).contains(move.angle),
              (0...100).contains(move.power) else { return false }

        var craft = self.craft(for: actor)
        let fuelSpent = move.power == 0 ? 0 : max(1, Int(ceil(Double(move.power) / 12.0)))
        guard craft.fuel >= fuelSpent else { return false }

        let radians = Double(move.angle) * .pi / 180
        let burn = Double(move.power) * 0.72
        craft.velocity.x += cos(radians) * burn
        craft.velocity.y += sin(radians) * burn
        craft.fuel -= fuelSpent

        let relay = relayPoint(sessionID: sessionID)
        var captured = false
        var boundaryHits = 0
        var wellWarning = false
        var path: [OrbitRelayPoint] = [craft.position]
        path.reserveCapacity(42)

        for step in 0..<Self.simulationSteps {
            let dx = Self.center.x - craft.position.x
            let dy = Self.center.y - craft.position.y
            let distanceSquared = max(7_500.0, dx * dx + dy * dy)
            let distance = sqrt(distanceSquared)
            let acceleration = Self.gravityCoefficient / distanceSquared
            craft.velocity.x += (dx / distance) * acceleration * Self.fixedTimeStep
            craft.velocity.y += (dy / distance) * acceleration * Self.fixedTimeStep

            craft.position.x += craft.velocity.x * Self.fixedTimeStep
            craft.position.y += craft.velocity.y * Self.fixedTimeStep

            if craft.position.x < 18 {
                craft.position.x = 18
                craft.velocity.x = abs(craft.velocity.x) * 0.74
                boundaryHits += 1
            } else if craft.position.x > Self.fieldWidth - 18 {
                craft.position.x = Self.fieldWidth - 18
                craft.velocity.x = -abs(craft.velocity.x) * 0.74
                boundaryHits += 1
            }
            if craft.position.y < 18 {
                craft.position.y = 18
                craft.velocity.y = abs(craft.velocity.y) * 0.74
                boundaryHits += 1
            } else if craft.position.y > Self.fieldHeight - 18 {
                craft.position.y = Self.fieldHeight - 18
                craft.velocity.y = -abs(craft.velocity.y) * 0.74
                boundaryHits += 1
            }

            let wellDistance = craft.position.distance(to: Self.center)
            if wellDistance < Self.exclusionRadius {
                wellWarning = true
                let nx = (craft.position.x - Self.center.x) / max(1, wellDistance)
                let ny = (craft.position.y - Self.center.y) / max(1, wellDistance)
                craft.position.x = Self.center.x + nx * Self.exclusionRadius
                craft.position.y = Self.center.y + ny * Self.exclusionRadius
                craft.velocity.x += nx * 22
                craft.velocity.y += ny * 22
                craft.stability = max(0, craft.stability - 1)
            }

            if !captured, craft.position.distance(to: relay) <= Self.relayCaptureRadius {
                captured = true
                craft.score += 1
            }

            if step % 8 == 0 {
                path.append(craft.position)
            }
        }

        if boundaryHits > 0 {
            craft.stability = max(0, craft.stability - min(2, boundaryHits))
        }

        if actor == .host { hostCraft = craft }
        else { guestCraft = craft }

        if captured { relayIndex += 1 }
        turn += 1
        lastTurn = OrbitRelayTurnResult(
            actor: actor,
            move: move,
            capturedRelay: captured,
            boundaryHits: boundaryHits,
            wellWarning: wellWarning,
            fuelSpent: fuelSpent,
            path: path
        )

        resolveOutcome(after: actor)
        return true
    }

    private mutating func resolveOutcome(after actor: MiniGamePlayer) {
        let active = craft(for: actor)
        if active.score >= Self.winningScore {
            winner = actor
            return
        }
        if active.stability <= 0 {
            winner = actor.opponent
            return
        }

        if turn >= Self.maximumTurns {
            let hostRank = hostCraft.score * 10_000 + hostCraft.stability * 100 + hostCraft.fuel
            let guestRank = guestCraft.score * 10_000 + guestCraft.stability * 100 + guestCraft.fuel
            if hostRank > guestRank { winner = .host }
            else if guestRank > hostRank { winner = .guest }
            else { isDraw = true }
            return
        }

        currentPlayer = actor.opponent
    }

    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}

enum OrbitRelayBot {
    static func chooseMove(
        in state: OrbitRelayState,
        actor: MiniGamePlayer,
        sessionID: String
    ) -> OrbitRelayMove? {
        guard !state.isFinished,
              state.currentPlayer == actor,
              !sessionID.isEmpty else { return nil }

        var best: (move: OrbitRelayMove, score: Double)?

        for angle in stride(from: 0, to: 360, by: 15) {
            for power in stride(from: 0, through: 100, by: 20) {
                let move = OrbitRelayMove(angle: angle, power: power)
                var candidate = state
                guard candidate.apply(move: move, actor: actor, sessionID: sessionID) else { continue }

                let craft = candidate.craft(for: actor)
                let relay = candidate.relayPoint(sessionID: sessionID)
                let distance = craft.position.distance(to: relay)
                let captured = candidate.lastTurn?.capturedRelay == true
                let warning = candidate.lastTurn?.wellWarning == true
                let hits = candidate.lastTurn?.boundaryHits ?? 0
                let value = (candidate.winner == actor ? 10_000_000.0 : 0)
                    + (captured ? 1_000_000.0 : 0)
                    + Double(craft.score) * 100_000
                    + Double(craft.stability) * 6_000
                    + Double(craft.fuel) * 18
                    - distance * 14
                    - (warning ? 55_000 : 0)
                    - Double(hits) * 18_000

                if best == nil || value > best!.score {
                    best = (move, value)
                }
            }
        }

        guard let move = best?.move else { return nil }
        var legalityProbe = state
        return legalityProbe.apply(move: move, actor: actor, sessionID: sessionID)
            ? move
            : nil
    }
}
