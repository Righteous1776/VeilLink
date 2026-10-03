import Foundation

enum AgentGameRegistry {
    static let trainingEnabledKinds: [MiniGameKind] = [.gomoku, .xiangqi, .ludo]
    static let dedicatedLocalPolicyKinds: [MiniGameKind] = [.tactical, .artillery, .lightTrail, .magneticHockey]

    static func isTrainingEnabled(_ kind: MiniGameKind) -> Bool {
        trainingEnabledKinds.contains(kind)
    }

    static func hasDedicatedLocalPolicy(_ kind: MiniGameKind) -> Bool {
        dedicatedLocalPolicyKinds.contains(kind)
    }

    static func exclusionReason(for kind: MiniGameKind) -> String? {
        switch kind {
        case .tactical:
            return "三国兵棋不进入通用棋类模型，改用独立训练、完全离线的 TacticalBot 策略。"
        case .artillery:
            return "弧光炮战不进入通用棋类模型，改用受规则引擎校验的本地弹道搜索 Bot。"
        case .lightTrail:
            return "光轨突围不进入通用棋类模型，改用受规则引擎校验的本地赛道预判 Bot。"
        case .magneticHockey:
            return "磁轨冰球不进入通用棋类模型，改用受规则引擎校验的本地物理搜索 Bot。"
        default:
            return nil
        }
    }
}
