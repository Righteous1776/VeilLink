import Foundation

struct TacticalBotMove: Equatable, Sendable {
    let from: Int?
    let to: Int?
    let score: Double
    let candidates: Int
    let policyID: String

    var isPass: Bool { from == nil && to == nil }
}

enum TacticalBotDifficulty: String, CaseIterable, Identifiable, Sendable {
    case recruit
    case commander
    case strategist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recruit: return "新兵"
        case .commander: return "都督"
        case .strategist: return "军师"
        }
    }

    var detail: String {
        switch self {
        case .recruit: return "会犯可控的小失误，适合第一局"
        case .commander: return "完整评估目标、补给与战损"
        case .strategist: return "第一道命令会联算本阶段后续行动"
        }
    }
}

/// A compact, install-local policy for the original 7×9 tactical game. The policy only ranks
/// commands produced by `TacticalState`; the selected command is applied to a copy once more
/// before it is returned. This keeps learned preferences behind the canonical rules gate.
enum TacticalBot {
    struct Policy: Codable, Equatable, Sendable {
        let schema: Int
        let policyID: String
        let featureOrder: [String]
        let weights: [Double]
        let trainingExamples: Int
        let trainingEpochs: Int

        static let expectedFeatures = [
            "bias", "win", "loss", "victoryPointDelta", "materialDelta",
            "objectiveControlDelta", "objectivePressureDelta", "supplyDelta",
            "commandSafetyDelta", "enemyCommandThreatDelta", "hqProgressDelta", "pass"
        ]

        static let fallback = Policy(
            schema: 1,
            policyID: "tactical-linear-v1-fallback",
            featureOrder: expectedFeatures,
            weights: [0.03, 18.0, -18.0, 2.9, 2.35, 1.8, 0.72, 0.44, 1.25, 1.05, 0.31, -1.4],
            trainingExamples: 0,
            trainingEpochs: 0
        )

        static func bundled(bundle: Bundle = .main) -> Policy {
            guard let url = bundle.url(forResource: "TacticalBotPolicyV1", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let policy = try? JSONDecoder().decode(Policy.self, from: data),
                  policy.schema == 1,
                  policy.featureOrder == expectedFeatures,
                  policy.weights.count == expectedFeatures.count,
                  policy.weights.allSatisfy(\.isFinite) else {
                return fallback
            }
            return policy
        }
    }

    private struct Command {
        let from: Int?
        let to: Int?

        var tieBreak: (Int, Int) { (from ?? Int.max, to ?? Int.max) }
    }

    private struct PositionMetrics {
        let victoryPoints: Double
        let material: Double
        let objectiveControl: Double
        let objectivePressure: Double
        let supplied: Double
        let commandSafety: Double
        let enemyCommandThreat: Double
        let hqProgress: Double
    }

    private static let installedPolicy = Policy.bundled()

    static var installedPolicyID: String { installedPolicy.policyID }

    static func chooseMove(
        in state: TacticalState,
        for player: MiniGamePlayer,
        sessionID: String,
        difficulty: TacticalBotDifficulty = .commander,
        policy: Policy? = nil
    ) -> TacticalBotMove? {
        guard state.winner == nil, !state.isDraw, state.currentPlayer == player else { return nil }
        let policy = policy ?? installedPolicy
        let commands = legalCommands(in: state, for: player)
        guard !commands.isEmpty else { return nil }

        let before = metrics(state, player: player)
        var ranked: [(command: Command, score: Double)] = []
        for command in commands {
            var next = state
            guard next.apply(from: command.from, to: command.to, actor: player, sessionID: sessionID) else { continue }
            let features = featureVector(
                before: before,
                after: metrics(next, player: player),
                next: next,
                player: player,
                isPass: command.from == nil
            )
            ranked.append((command, weightedScore(features, policy: policy)))
        }
        ranked.sort { lhs, rhs in
            if abs(lhs.score - rhs.score) > 0.000_001 { return lhs.score > rhs.score }
            return isEarlier(lhs.command, than: rhs.command)
        }
        if difficulty == .strategist {
            // Bound continuation search to the strongest immediate roots so older devices do not
            // multiply every legal command by another full legal-command scan.
            for index in 0..<min(8, ranked.count) {
                let command = ranked[index].command
                var next = state
                guard next.apply(from: command.from, to: command.to, actor: player, sessionID: sessionID),
                      next.currentPlayer == player, next.winner == nil, !next.isDraw else { continue }
                ranked[index].score += 0.55 * bestContinuationScore(
                    in: next,
                    for: player,
                    sessionID: sessionID,
                    policy: policy
                )
            }
            ranked.sort { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.000_001 { return lhs.score > rhs.score }
                return isEarlier(lhs.command, than: rhs.command)
            }
        }
        guard !ranked.isEmpty else { return nil }
        // Recruit deliberately chooses the third-ranked legal command when possible. This gives
        // beginners breathing room without randomness, cheating or a separate weakened ruleset.
        let selectedIndex = difficulty == .recruit ? min(2, ranked.count - 1) : 0
        let best = ranked[selectedIndex]

        // Final rule gate: a malformed or incompatible policy can never emit an illegal order.
        var validation = state
        guard validation.apply(
            from: best.command.from,
            to: best.command.to,
            actor: player,
            sessionID: sessionID
        ) else { return nil }
        return TacticalBotMove(
            from: best.command.from,
            to: best.command.to,
            score: best.score,
            candidates: commands.count,
            policyID: "\(policy.policyID)-\(difficulty.rawValue)"
        )
    }

    static func legalCommandCount(in state: TacticalState, for player: MiniGamePlayer) -> Int {
        legalCommands(in: state, for: player).count
    }

    private static func legalCommands(in state: TacticalState, for player: MiniGamePlayer) -> [Command] {
        var commands: [Command] = []
        for unit in state.units(for: player).sorted(by: { $0.position < $1.position }) {
            for destination in state.legalDestinations(from: unit.position, actor: player).sorted() {
                commands.append(Command(from: unit.position, to: destination))
            }
        }
        // Ending an activation is always legal and sometimes correct when another move would
        // expose the command counter or abandon a scoring objective.
        commands.append(Command(from: nil, to: nil))
        return commands
    }

    private static func featureVector(
        before: PositionMetrics,
        after: PositionMetrics,
        next: TacticalState,
        player: MiniGamePlayer,
        isPass: Bool
    ) -> [Double] {
        [
            1,
            next.winner == player ? 1 : 0,
            next.winner == player.opponent ? 1 : 0,
            after.victoryPoints - before.victoryPoints,
            after.material - before.material,
            after.objectiveControl - before.objectiveControl,
            after.objectivePressure - before.objectivePressure,
            after.supplied - before.supplied,
            after.commandSafety - before.commandSafety,
            after.enemyCommandThreat - before.enemyCommandThreat,
            after.hqProgress - before.hqProgress,
            isPass ? 1 : 0
        ]
    }

    private static func bestContinuationScore(
        in state: TacticalState,
        for player: MiniGamePlayer,
        sessionID: String,
        policy: Policy
    ) -> Double {
        let before = metrics(state, player: player)
        var best = -Double.greatestFiniteMagnitude
        for command in legalCommands(in: state, for: player) {
            var next = state
            guard next.apply(from: command.from, to: command.to, actor: player, sessionID: sessionID) else { continue }
            let features = featureVector(
                before: before,
                after: metrics(next, player: player),
                next: next,
                player: player,
                isPass: command.from == nil
            )
            best = max(best, weightedScore(features, policy: policy))
        }
        return best.isFinite ? best : 0
    }

    private static func weightedScore(_ features: [Double], policy: Policy) -> Double {
        zip(features, policy.weights).reduce(0.0) { $0 + $1.0 * $1.1 }
    }

    private static func metrics(_ state: TacticalState, player: MiniGamePlayer) -> PositionMetrics {
        let faction: TacticalFaction = player == .host ? .cao : .yuan
        let opponent = faction.opponent
        let ownUnits = state.units(for: player)
        let enemyUnits = state.units(for: player.opponent)
        func unitValue(_ unit: TacticalUnit) -> Double {
            let kind: Double
            switch unit.kind {
            case .command: kind = 7
            case .cavalry: kind = 4
            case .infantry: kind = 3.5
            case .ranged: kind = 3
            case .supply: kind = 2.5
            }
            return kind * Double(unit.steps)
        }

        let objectives = TacticalState.hexes.filter(\.isObjective)
        let ownControl = objectives.reduce(0.0) { value, hex in
            value + (state.control(at: hex.index) == faction ? Double(hex.objectiveValue) : 0)
        }
        let enemyControl = objectives.reduce(0.0) { value, hex in
            value + (state.control(at: hex.index) == opponent ? Double(hex.objectiveValue) : 0)
        }
        let pressure = objectives.reduce(0.0) { value, hex in
            let p = state.objectivePressure(at: hex.index)
            let delta = faction == .cao ? p.caoStrength - p.yuanStrength : p.yuanStrength - p.caoStrength
            return value + Double(delta * hex.objectiveValue)
        }
        let ownCommand = ownUnits.first(where: { $0.kind == .command })
        let enemyCommand = enemyUnits.first(where: { $0.kind == .command })
        let commandSafety = ownCommand.map { command in
            Double(command.steps * 2) - Double(state.threatStrengths(by: opponent)[command.position, default: 0])
        } ?? -8
        let enemyCommandThreat = enemyCommand.map {
            Double(state.threatStrengths(by: faction)[$0.position, default: 0]) - Double($0.steps)
        } ?? 8
        let enemyHQ = TacticalState.hexes.first(where: { $0.headquarters == opponent })?.index
        let hqProgress = enemyHQ.map { headquarters in
            ownUnits.filter { $0.kind != .supply }.reduce(0.0) {
                $0 + 1.0 / Double(1 + TacticalState.hexDistance($1.position, headquarters))
            }
        } ?? 0

        return PositionMetrics(
            victoryPoints: Double(state.victoryPoints(for: player) - state.victoryPoints(for: player.opponent)),
            material: ownUnits.reduce(0.0) { $0 + unitValue($1) } - enemyUnits.reduce(0.0) { $0 + unitValue($1) },
            objectiveControl: ownControl - enemyControl,
            objectivePressure: pressure,
            supplied: Double(ownUnits.filter { state.isSupplied(unitID: $0.id) }.count - enemyUnits.filter { state.isSupplied(unitID: $0.id) }.count),
            commandSafety: commandSafety,
            enemyCommandThreat: enemyCommandThreat,
            hqProgress: hqProgress
        )
    }

    private static func isEarlier(_ lhs: Command, than rhs: Command) -> Bool {
        if lhs.tieBreak.0 != rhs.tieBreak.0 { return lhs.tieBreak.0 < rhs.tieBreak.0 }
        return lhs.tieBreak.1 < rhs.tieBreak.1
    }
}
