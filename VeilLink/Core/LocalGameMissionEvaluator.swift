import Foundation

struct LocalGameMissionProgress: Equatable {
    let fraction: Double
    let label: String

    var completed: Bool { fraction >= 0.999 }

    init(fraction: Double, label: String) {
        self.fraction = min(1, max(0, fraction))
        self.label = label
    }
}

enum LocalGameMissionEvaluator {
    static func progress(
        for mission: LocalGameMission,
        session: MiniGameSessionSnapshot
    ) -> LocalGameMissionProgress {
        let player = session.localPlayer
        switch session.game {
        case .gomoku:
            guard let state = session.gomoku else { return pending() }
            return gomoku(mission: mission, state: state, player: player)
        case .xiangqi:
            guard let state = session.xiangqi else { return pending() }
            return xiangqi(mission: mission, state: state, player: player)
        case .ludo:
            guard let state = session.ludo else { return pending() }
            return ludo(mission: mission, state: state, player: player)
        case .tactical:
            guard let state = session.tactical else { return pending() }
            return tactical(mission: mission, state: state, player: player)
        case .artillery:
            guard let state = session.artillery else { return pending() }
            return artillery(mission: mission, state: state, player: player)
        case .lightTrail:
            guard let state = session.lightTrail else { return pending() }
            return lightTrail(mission: mission, state: state, player: player)
        case .magneticHockey:
            guard let state = session.magneticHockey else { return pending() }
            return magneticHockey(mission: mission, state: state, player: player)
        }
    }

    private static func gomoku(
        mission: LocalGameMission,
        state: GomokuState,
        player: MiniGamePlayer
    ) -> LocalGameMissionProgress {
        let value: Int8 = player == .host ? 1 : 2
        switch mission.code {
        case "CENTER_LOCK":
            var count = 0
            for row in 5...9 {
                for col in 5...9 where state.value(at: row * GomokuState.size + col) == value {
                    count += 1
                }
            }
            return .init(fraction: Double(count) / 4.0, label: "中央落子 \(count)/4")
        case "DOUBLE_THREAT":
            let line = longestLine(in: state, value: value)
            return .init(fraction: Double(line) / 4.0, label: "最长连续 \(line)/4")
        default:
            let stones = (0..<(GomokuState.size * GomokuState.size))
                .filter { state.value(at: $0) == value }
                .count
            return .init(fraction: Double(stones) / 6.0, label: "已布子 \(stones)/6")
        }
    }

    private static func xiangqi(
        mission: LocalGameMission,
        state: XiangqiState,
        player: MiniGamePlayer
    ) -> LocalGameMissionProgress {
        switch mission.code {
        case "KING_SAFETY":
            let safe = !state.isInCheck(player: player)
            let tempo = min(1, Double(state.moveCount) / 6.0)
            return .init(
                fraction: safe ? max(0.35, tempo) : 0,
                label: safe ? "将帅安全 · 第 \(state.moveCount) 手" : "正在被将军"
            )
        case "OPEN_FILE":
            let opponentSide: XiangqiSide = player == .host ? .black : .red
            let remaining = (0..<(XiangqiState.rows * XiangqiState.columns))
                .compactMap { state.piece(at: $0) }
                .filter { $0.side == opponentSide }
                .count
            let captured = max(0, 16 - remaining)
            return .init(fraction: Double(captured) / 2.0, label: "吃子 \(captured)/2")
        default:
            let checks = state.consecutiveCheckCount(for: player)
            return .init(fraction: Double(checks) / 2.0, label: "连续将军 \(checks)/2")
        }
    }

    private static func ludo(
        mission: LocalGameMission,
        state: LudoState,
        player: MiniGamePlayer
    ) -> LocalGameMissionProgress {
        let pieces = state.pieces(for: player)
        switch mission.code {
        case "SAFE_ROUTE":
            let advanced = pieces.filter { $0 >= 12 }.count
            return .init(fraction: Double(advanced) / 2.0, label: "深入赛道 \(advanced)/2")
        case "BALANCED_FIELD":
            let deployed = pieces.filter { $0 >= 0 && $0 < LudoState.finishProgress }.count
            return .init(fraction: Double(deployed) / 2.0, label: "在场棋子 \(deployed)/2")
        default:
            let finished = state.finishedCount(for: player)
            return .init(fraction: Double(finished), label: "抵达终点 \(finished)/1")
        }
    }

    private static func tactical(
        mission: LocalGameMission,
        state: TacticalState,
        player: MiniGamePlayer
    ) -> LocalGameMissionProgress {
        let faction: TacticalFaction = player == .host ? .cao : .yuan
        let situation = state.situationSnapshot()
        switch mission.code {
        case "SUPPLY_FIRST":
            let units = state.units(for: player)
            guard !units.isEmpty else { return .init(fraction: 0, label: "无可用部队") }
            let supplied = units.filter(situation.isSupplied).count
            return .init(
                fraction: Double(supplied) / Double(units.count),
                label: "补给 \(supplied)/\(units.count)"
            )
        case "OBJECTIVE_NET":
            let vp = state.victoryPoints(for: player)
            return .init(fraction: Double(vp) / 4.0, label: "战役点数 \(vp)/4")
        default:
            guard let command = state.units(for: player).first(where: { $0.kind == .command }) else {
                return .init(fraction: 0, label: "中军已失")
            }
            let threatened = situation.threatenedHexes(by: faction.opponent).contains(command.position)
            return .init(
                fraction: threatened ? 0.25 : 1,
                label: threatened ? "中军受威胁" : "中军安全"
            )
        }
    }

    private static func artillery(
        mission: LocalGameMission,
        state: ArtilleryState,
        player: MiniGamePlayer
    ) -> LocalGameMissionProgress {
        guard let shot = state.lastShot else { return pending() }
        switch mission.code {
        case "WIND_READ":
            return .init(
                fraction: shot.damage > 0 ? 1 : 0.45,
                label: shot.damage > 0 ? "校射命中" : "已建立落点"
            )
        case "LOW_ARC":
            let success = shot.angle <= 42 && shot.damage > 0
            return .init(
                fraction: success ? 1 : (shot.angle <= 42 ? 0.55 : 0.2),
                label: "末炮 \(shot.angle)° · \(shot.damage)伤害"
            )
        default:
            let disciplined = shot.power <= 82
            let fraction = shot.damage > 0 && disciplined ? 1 : (disciplined ? 0.6 : 0.25)
            return .init(
                fraction: fraction,
                label: "末炮 \(shot.power)% · \(shot.damage)伤害"
            )
        }
    }

    private static func lightTrail(
        mission: LocalGameMission,
        state: LightTrailState,
        player: MiniGamePlayer
    ) -> LocalGameMissionProgress {
        switch mission.code {
        case "ENERGY_BANK":
            let energy = state.energy(for: player)
            return .init(fraction: Double(energy) / 2.0, label: "能量 \(energy)/2")
        case "LANE_READ":
            let shield = state.shield(for: player)
            let fraction = Double(shield) / 3.0
            return .init(fraction: fraction, label: "护盾 \(shield)/3 · 第 \(state.round) 轮")
        default:
            let survived = !state.lastCollision
            let fraction = state.round == 0 ? 0 : (survived ? min(1, Double(state.round) / 5.0) : 0.2)
            return .init(
                fraction: fraction,
                label: survived ? "连续安全 · 第 \(state.round) 轮" : "刚发生碰撞"
            )
        }
    }

    private static func magneticHockey(
        mission: LocalGameMission,
        state: MagneticHockeyState,
        player: MiniGamePlayer
    ) -> LocalGameMissionProgress {
        switch mission.code {
        case "FIELD_READ":
            guard let shot = state.lastShot else { return pending() }
            let ownGoal = shot.scoredPlayer == player.opponent
            return .init(
                fraction: ownGoal ? 0 : min(1, Double(state.turn) / 3.0),
                label: ownGoal ? "出现反向进球风险" : "磁场处理稳定"
            )
        case "BANK_SHOT":
            guard let shot = state.lastShot else { return pending() }
            let scored = shot.scoredPlayer == player
            let fraction = scored && shot.wallBounces > 0 ? 1 : (shot.wallBounces > 0 ? 0.65 : 0.2)
            return .init(
                fraction: fraction,
                label: "反弹 \(shot.wallBounces) · " + (scored ? "得分" : "未得分")
            )
        default:
            let score = state.score(for: player)
            return .init(fraction: Double(score), label: "进球 \(score)/1")
        }
    }

    private static func pending() -> LocalGameMissionProgress {
        .init(fraction: 0, label: "等待第一步操作")
    }

    private static func longestLine(in state: GomokuState, value: Int8) -> Int {
        let size = GomokuState.size
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
        var best = 0
        for row in 0..<size {
            for col in 0..<size {
                guard state.value(at: row * size + col) == value else { continue }
                for (dr, dc) in directions {
                    var count = 1
                    var r = row + dr
                    var c = col + dc
                    while (0..<size).contains(r),
                          (0..<size).contains(c),
                          state.value(at: r * size + c) == value {
                        count += 1
                        r += dr
                        c += dc
                    }
                    best = max(best, count)
                }
            }
        }
        return best
    }
}
