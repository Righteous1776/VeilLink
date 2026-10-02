import Foundation

/// A compact, deterministic 2D physics core for turn-based magnetic hockey.
///
/// Angles use screen coordinates: 0 points right, 90 points down. The host
/// attacks the right goal and the guest attacks the left goal. Physics always
/// advances with the same fixed step so local play, replays, and peers rebuild
/// an identical state from the same session ID and commands.
struct MagneticHockeyPoint: Equatable, Sendable {
    let x: Double
    let y: Double
}

struct MagneticHockeyMove: Codable, Equatable, Sendable {
    let angle: Int
    let power: Int
}

struct MagneticHockeyShot: Equatable, Sendable {
    let move: MagneticHockeyMove
    let start: MagneticHockeyPoint
    let end: MagneticHockeyPoint
    let fixedStepCount: Int
    let wallBounces: Int
    let fieldPolarity: Int
    let scoredPlayer: MiniGamePlayer?
}

struct MagneticHockeyState: Equatable, Sendable {
    static let fieldWidth = 1_000.0
    static let fieldHeight = 600.0
    static let puckRadius = 18.0
    static let goalMinimumY = 218.0
    static let goalMaximumY = 382.0
    static let winningScore = 3
    static let maximumTurns = 20

    private static let fixedTimeStep = 1.0 / 120.0
    private static let maximumFixedSteps = 840
    private static let frictionPerStep = 0.994
    private static let sleepSpeed = 1.0

    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var hostScore = 0
    private(set) var guestScore = 0
    private(set) var turn = 0
    private(set) var puckPosition = MagneticHockeyPoint(x: fieldWidth / 2, y: fieldHeight / 2)
    private(set) var winner: MiniGamePlayer?
    private(set) var lastShot: MagneticHockeyShot?

    var isDraw: Bool {
        winner == nil && turn >= Self.maximumTurns && hostScore == guestScore
    }

    var isFinished: Bool { winner != nil || isDraw }

    func score(for player: MiniGamePlayer) -> Int {
        player == .host ? hostScore : guestScore
    }

    static func fieldPolarity(sessionID: String, turn: Int) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in Data("\(sessionID)|magnetic-hockey|\(turn)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % 7) - 3
    }

    @discardableResult
    mutating func apply(move: MagneticHockeyMove, actor: MiniGamePlayer, sessionID: String) -> Bool {
        apply(angle: move.angle, power: move.power, actor: actor, sessionID: sessionID)
    }

    @discardableResult
    mutating func apply(angle: Int, power: Int, actor: MiniGamePlayer, sessionID: String) -> Bool {
        guard !isFinished,
              actor == currentPlayer,
              !sessionID.isEmpty,
              (0..<360).contains(angle),
              (10...100).contains(power) else { return false }

        let move = MagneticHockeyMove(angle: angle, power: power)
        let start = puckPosition
        let polarity = Self.fieldPolarity(sessionID: sessionID, turn: turn)
        let radians = Double(angle) * .pi / 180
        let launchSpeed = Double(power) * 14
        var x = start.x
        var y = start.y
        var velocityX = cos(radians) * launchSpeed
        var velocityY = sin(radians) * launchSpeed
        var scoredPlayer: MiniGamePlayer?
        var wallBounces = 0
        var completedSteps = 0

        for step in 1...Self.maximumFixedSteps {
            // A very small deterministic Lorentz-like bend gives the magnetic
            // rails their identity without introducing non-replayable random input.
            let magneticScale = Double(polarity) * 0.025
            let accelerationX = -velocityY * magneticScale
            let accelerationY = velocityX * magneticScale
            velocityX += accelerationX * Self.fixedTimeStep
            velocityY += accelerationY * Self.fixedTimeStep
            velocityX *= Self.frictionPerStep
            velocityY *= Self.frictionPerStep
            x += velocityX * Self.fixedTimeStep
            y += velocityY * Self.fixedTimeStep
            completedSteps = step

            if y < Self.puckRadius {
                y = Self.puckRadius + (Self.puckRadius - y)
                velocityY = abs(velocityY)
                wallBounces += 1
            } else if y > Self.fieldHeight - Self.puckRadius {
                let edge = Self.fieldHeight - Self.puckRadius
                y = edge - (y - edge)
                velocityY = -abs(velocityY)
                wallBounces += 1
            }

            if x >= Self.fieldWidth && Self.isInsideGoalMouth(y) {
                x = Self.fieldWidth
                scoredPlayer = .host
                break
            }
            if x <= 0 && Self.isInsideGoalMouth(y) {
                x = 0
                scoredPlayer = .guest
                break
            }

            if x < Self.puckRadius && !Self.isInsideGoalMouth(y) {
                x = Self.puckRadius + (Self.puckRadius - x)
                velocityX = abs(velocityX)
                wallBounces += 1
            } else if x > Self.fieldWidth - Self.puckRadius && !Self.isInsideGoalMouth(y) {
                let edge = Self.fieldWidth - Self.puckRadius
                x = edge - (x - edge)
                velocityX = -abs(velocityX)
                wallBounces += 1
            }

            if hypot(velocityX, velocityY) < Self.sleepSpeed { break }
        }

        let end = MagneticHockeyPoint(
            x: min(Self.fieldWidth, max(0, x)),
            y: min(Self.fieldHeight, max(0, y))
        )
        lastShot = MagneticHockeyShot(
            move: move,
            start: start,
            end: end,
            fixedStepCount: completedSteps,
            wallBounces: wallBounces,
            fieldPolarity: polarity,
            scoredPlayer: scoredPlayer
        )

        if let scoredPlayer {
            if scoredPlayer == .host { hostScore += 1 }
            else { guestScore += 1 }
            puckPosition = MagneticHockeyPoint(x: Self.fieldWidth / 2, y: Self.fieldHeight / 2)
        } else {
            puckPosition = end
        }

        turn += 1
        resolveMatch(after: actor)
        return true
    }

    private static func isInsideGoalMouth(_ y: Double) -> Bool {
        (goalMinimumY...goalMaximumY).contains(y)
    }

    private mutating func resolveMatch(after actor: MiniGamePlayer) {
        if hostScore >= Self.winningScore {
            winner = .host
        } else if guestScore >= Self.winningScore {
            winner = .guest
        } else if turn >= Self.maximumTurns {
            if hostScore > guestScore { winner = .host }
            else if guestScore > hostScore { winner = .guest }
        } else {
            currentPlayer = actor.opponent
        }
    }
}

enum MagneticHockeyBot {
    /// Exhaustively evaluates the bot's documented 5-degree/5-power action
    /// grid. Every candidate, and the final result, must pass the same `apply`
    /// legality gate used by human and network commands.
    static func chooseMove(
        in state: MagneticHockeyState,
        actor: MiniGamePlayer,
        sessionID: String
    ) -> MagneticHockeyMove? {
        guard state.currentPlayer == actor, !state.isFinished, !sessionID.isEmpty else { return nil }

        let startingScore = state.score(for: actor)
        var best: (move: MagneticHockeyMove, score: Double)?

        for angle in stride(from: 0, to: 360, by: 5) {
            for power in stride(from: 10, through: 100, by: 5) {
                let move = MagneticHockeyMove(angle: angle, power: power)
                var candidate = state
                guard candidate.apply(move: move, actor: actor, sessionID: sessionID),
                      let shot = candidate.lastShot else { continue }

                let scored = candidate.score(for: actor) - startingScore
                let ownGoal = shot.scoredPlayer != nil && shot.scoredPlayer != actor
                let targetX = actor == .host ? MagneticHockeyState.fieldWidth : 0
                let targetY = (MagneticHockeyState.goalMinimumY + MagneticHockeyState.goalMaximumY) / 2
                let distanceToTarget = hypot(shot.end.x - targetX, shot.end.y - targetY)
                let progress = actor == .host ? shot.end.x : MagneticHockeyState.fieldWidth - shot.end.x
                let value = (candidate.winner == actor ? 10_000_000.0 : 0)
                    + Double(scored) * 1_000_000
                    - (ownGoal ? 2_000_000 : 0)
                    + progress * 10
                    - distanceToTarget
                    - Double(power) * 0.001

                if best == nil || value > best!.score {
                    best = (move, value)
                }
            }
        }

        guard let move = best?.move else { return nil }
        var legalityProbe = state
        return legalityProbe.apply(move: move, actor: actor, sessionID: sessionID) ? move : nil
    }
}
