import Foundation

enum AgentGameRegistry {
    static let trainingEnabledKinds: [MiniGameKind] = [.gomoku, .xiangqi, .ludo]
    static let dedicatedLocalPolicyKinds: [MiniGameKind] = [.tactical]

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
        default:
            return nil
        }
    }
}
