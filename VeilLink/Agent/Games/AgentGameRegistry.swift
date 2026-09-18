import Foundation

enum AgentGameRegistry {
    static let trainingEnabledKinds: [MiniGameKind] = [.gomoku, .xiangqi, .ludo]

    static func isTrainingEnabled(_ kind: MiniGameKind) -> Bool {
        trainingEnabledKinds.contains(kind)
    }

    static func exclusionReason(for kind: MiniGameKind) -> String? {
        switch kind {
        case .tactical:
            return "三国兵棋当前明确排除在训练集之外，等待玩法重构后重新评估。"
        default:
            return nil
        }
    }
}
