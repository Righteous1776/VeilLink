import Foundation

struct LocalGameMission: Equatable {
    let code: String
    let title: String
    let detail: String
    let systemImage: String
}

/// Session-seeded side objectives for local play.
/// This is intentionally meta-game only: it never changes legal moves, scoring,
/// replay data, network payloads or deterministic game state.
enum LocalGameMissionDirector {
    static func mission(for game: MiniGameKind, sessionID: String) -> LocalGameMission {
        let variant = Int(stableHash(sessionID + game.title) % 3)
        switch game {
        case .gomoku:
            return [
                LocalGameMission(code: "CENTER_LOCK", title: "中央封锁", detail: "优先争夺中央交叉区，逼电脑在外圈应对。", systemImage: "scope"),
                LocalGameMission(code: "DOUBLE_THREAT", title: "双向威胁", detail: "尝试制造两个必须同时回应的潜在连线。", systemImage: "point.3.filled.connected.trianglepath.dotted"),
                LocalGameMission(code: "QUIET_BUILD", title: "静默筑势", detail: "减少无效追击，用连续两手构建后续强制线。", systemImage: "square.grid.3x3.fill")
            ][variant]
        case .xiangqi:
            return [
                LocalGameMission(code: "KING_SAFETY", title: "将帅安全", detail: "先稳定中路与底线，再把主动权转向边翼。", systemImage: "shield.lefthalf.filled"),
                LocalGameMission(code: "OPEN_FILE", title: "打开纵线", detail: "争取让车或炮获得一条高价值纵向通道。", systemImage: "arrow.up.and.down"),
                LocalGameMission(code: "TEMPO_CHAIN", title: "连续先手", detail: "让至少两步形成连续威胁，而不是单次交换。", systemImage: "bolt.horizontal.fill")
            ][variant]
        case .ludo:
            return [
                LocalGameMission(code: "SAFE_ROUTE", title: "安全推进", detail: "优先让领先棋子进入更安全的阶段，减少暴露。", systemImage: "figure.walk"),
                LocalGameMission(code: "BALANCED_FIELD", title: "双子推进", detail: "不要只押一枚棋子，保持至少两枚持续向前。", systemImage: "person.2.fill"),
                LocalGameMission(code: "FINISH_PRESSURE", title: "终局压力", detail: "一旦形成领先，优先把可终结的棋子送进终点区。", systemImage: "flag.checkered")
            ][variant]
        case .tactical:
            return [
                LocalGameMission(code: "SUPPLY_FIRST", title: "粮道优先", detail: "保持主力补给不断，再把前线压力推向官渡。", systemImage: "shippingbox.fill"),
                LocalGameMission(code: "OBJECTIVE_NET", title: "目标网", detail: "争夺官渡的同时，让另一支部队威胁白马或乌巢。", systemImage: "map.fill"),
                LocalGameMission(code: "COMMAND_GUARD", title: "中军护卫", detail: "避免中军孤立，用友军形成支援链和反击空间。", systemImage: "shield.checkered")
            ][variant]
        case .artillery:
            return [
                LocalGameMission(code: "WIND_READ", title: "读风校射", detail: "第一炮先建立风偏基准，第二炮再做精确修正。", systemImage: "wind"),
                LocalGameMission(code: "LOW_ARC", title: "低弧压制", detail: "尝试在不过度牺牲精度的前提下降低弹道时间。", systemImage: "arrow.down.right"),
                LocalGameMission(code: "POWER_DISCIPLINE", title: "火力纪律", detail: "优先微调力度而不是同时大幅改变两个参数。", systemImage: "dial.medium.fill")
            ][variant]
        case .lightTrail:
            return [
                LocalGameMission(code: "ENERGY_BANK", title: "能量储备", detail: "减少无意义换道，把能量留给连续障碍区。", systemImage: "battery.75percent"),
                LocalGameMission(code: "LANE_READ", title: "赛道预判", detail: "提前读取两段路线，不要等障碍贴近才变道。", systemImage: "road.lanes"),
                LocalGameMission(code: "CLEAN_LINE", title: "洁净路线", detail: "追求连续安全换道，避免短时间内反复左右修正。", systemImage: "waveform.path")
            ][variant]
        case .magneticHockey:
            return [
                LocalGameMission(code: "FIELD_READ", title: "磁场读秒", detail: "观察本回合偏转方向，再选择直射或借边。", systemImage: "dot.radiowaves.left.and.right"),
                LocalGameMission(code: "BANK_SHOT", title: "边墙借力", detail: "在角度允许时，用一次反弹改变入射方向。", systemImage: "arrow.turn.down.right"),
                LocalGameMission(code: "CENTER_CONTROL", title: "中线控制", detail: "尽量让球在出手后穿过中轴附近，保留二次机会。", systemImage: "circle.grid.cross.fill")
            ][variant]
        }
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
