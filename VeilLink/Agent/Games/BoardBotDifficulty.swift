import Foundation

enum BoardBotDifficulty: String, CaseIterable, Identifiable, Sendable {
    case trainee
    case strategist
    case master

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trainee: return "训练"
        case .strategist: return "标准"
        case .master: return "大师"
        }
    }

    var telemetryLabel: String {
        switch self {
        case .trainee: return "LIGHT"
        case .strategist: return "TACTICAL"
        case .master: return "DEEP"
        }
    }

    func gomokuBudget(profileLabel: String) -> GomokuBotBudget {
        let base = GomokuBotBudget.standard(profileLabel: profileLabel)
        switch self {
        case .trainee:
            return GomokuBotBudget(
                candidateRadius: 1,
                rootCandidateLimit: max(8, base.rootCandidateLimit / 2),
                replyCandidateLimit: max(5, base.replyCandidateLimit / 2),
                timeLimitMilliseconds: max(80, base.timeLimitMilliseconds / 2)
            )
        case .strategist:
            return base
        case .master:
            return GomokuBotBudget(
                candidateRadius: 2,
                rootCandidateLimit: min(36, base.rootCandidateLimit + 8),
                replyCandidateLimit: min(22, base.replyCandidateLimit + 6),
                timeLimitMilliseconds: min(450, base.timeLimitMilliseconds + 140)
            )
        }
    }

    func xiangqiBudget(profileLabel: String) -> XiangqiBotBudget {
        let base = XiangqiBotBudget.standard(profileLabel: profileLabel)
        switch self {
        case .trainee:
            return XiangqiBotBudget(
                maxDepth: max(3, base.maxDepth - 2),
                quiescenceDepth: max(0, base.quiescenceDepth - 1),
                timeLimitMilliseconds: max(100, Int(Double(base.timeLimitMilliseconds) * 0.60))
            )
        case .strategist:
            return base
        case .master:
            return XiangqiBotBudget(
                maxDepth: min(7, base.maxDepth + 1),
                quiescenceDepth: min(3, base.quiescenceDepth + 1),
                timeLimitMilliseconds: min(560, base.timeLimitMilliseconds + 160)
            )
        }
    }

    func telemetryDetail(profileLabel: String, game: MiniGameKind) -> String {
        switch game {
        case .gomoku:
            let budget = gomokuBudget(profileLabel: profileLabel)
            return "候选 \(budget.rootCandidateLimit) · 回复 \(budget.replyCandidateLimit) · \(budget.timeLimitMilliseconds)ms"
        case .xiangqi:
            let budget = xiangqiBudget(profileLabel: profileLabel)
            return "深度 D\(budget.maxDepth) · 静态延伸 \(budget.quiescenceDepth) · \(budget.timeLimitMilliseconds)ms"
        case .ludo:
            switch self {
            case .trainee: return "首个合法棋子 · 无反制评估"
            case .strategist: return "单步收益评分"
            case .master: return "单步收益 + 对手最佳回复风险"
            }
        default:
            return ""
        }
    }
}
