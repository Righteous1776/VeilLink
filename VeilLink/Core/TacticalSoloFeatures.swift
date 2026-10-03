import Foundation

enum TacticalSoloScenario: String, CaseIterable, Identifiable, Sendable {
    case standard
    case daily

    var id: String { rawValue }
    var title: String { self == .standard ? "经典官渡" : "今日战局" }
}

struct TacticalDailyChallenge: Equatable, Sendable {
    let dayID: String
    let title: String
    let briefing: String
    let medalGoal: String
    let variant: Int

    static func challenge(on date: Date = Date()) -> TacticalDailyChallenge {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let day = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        let variant = ((day % 4) + 4) % 4
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        switch variant {
        case 0:
            return TacticalDailyChallenge(dayID: formatter.string(from: date), title: "先锋接敌", briefing: "双方骑军已经前出，白马方向开局即进入争夺。", medalGoal: "在第 6 轮结束前取胜", variant: variant)
        case 1:
            return TacticalDailyChallenge(dayID: formatter.string(from: date), title: "粮道危局", briefing: "双方粮队被迫前移，护粮与断粮同样重要。", medalGoal: "己方粮队存活并获胜", variant: variant)
        case 2:
            return TacticalDailyChallenge(dayID: formatter.string(from: date), title: "争渡先机", briefing: "两翼步军靠近渡口，中央会更早爆发接触。", medalGoal: "占领官渡并获胜", variant: variant)
        default:
            return TacticalDailyChallenge(dayID: formatter.string(from: date), title: "中军对峙", briefing: "中军向前督战，指挥支援更强，但斩将风险也更高。", medalGoal: "中军不损失任何一步并获胜", variant: variant)
        }
    }

    func makeState() -> TacticalState {
        var units = TacticalState.initialUnits
        func move(_ id: String, to position: Int) {
            guard let index = units.firstIndex(where: { $0.id == id }) else { return }
            units[index].position = position
        }
        switch variant {
        case 0:
            move("cao-cavalry", to: 40)
            move("yuan-cavalry", to: 22)
        case 1:
            move("cao-supply", to: 46)
            move("yuan-supply", to: 16)
        case 2:
            move("cao-infantry-l", to: 38)
            move("yuan-infantry-r", to: 24)
        default:
            move("cao-command", to: 46)
            move("yuan-command", to: 16)
        }
        return TacticalState(units: units)
    }
}

struct TacticalDebrief: Equatable, Sendable {
    let headline: String
    let summary: String
    let medals: [String]

    static func make(state: TacticalState, humanPlayer: MiniGamePlayer, challenge: TacticalDailyChallenge?) -> TacticalDebrief {
        let won = state.winner == humanPlayer
        let ownUnits = state.units(for: humanPlayer)
        let ownVP = state.victoryPoints(for: humanPlayer)
        let enemyVP = state.victoryPoints(for: humanPlayer.opponent)
        var medals: [String] = []
        if won { medals.append("官渡凯旋") }
        if won && state.round <= 6 { medals.append("神速") }
        if won && ownUnits.count == 6 { medals.append("全军而还") }
        if ownVP >= TacticalState.victoryPointsToWin { medals.append("据点大师") }
        if let challenge, dailyGoalMet(challenge: challenge, state: state, humanPlayer: humanPlayer) {
            medals.append("今日军令")
        }
        if medals.isEmpty { medals.append("再整旗鼓") }
        return TacticalDebrief(
            headline: won ? "曹军奏捷" : (state.isDraw ? "两军罢战" : "袁军守住战场"),
            summary: "历经 \(min(state.round, TacticalState.maxRounds)) 轮，曹军 \(ownVP) VP · 袁军 \(enemyVP) VP，己方尚存 \(ownUnits.count) 支部队。",
            medals: medals
        )
    }

    private static func dailyGoalMet(challenge: TacticalDailyChallenge, state: TacticalState, humanPlayer: MiniGamePlayer) -> Bool {
        guard state.winner == humanPlayer else { return false }
        switch challenge.variant {
        case 0: return state.round <= 6
        case 1: return state.unit(id: "cao-supply") != nil
        case 2: return state.control(at: 31) == .cao
        default: return state.unit(id: "cao-command")?.steps == TacticalUnitKind.command.maxSteps
        }
    }
}
