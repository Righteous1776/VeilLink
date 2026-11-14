import Foundation

/// Search budgets for four original plus three optional Gomoku-only compute tiers.
/// Every level uses the same fitted ordering and mandatory tactical gates.
/// These are measured-compute levels, never strength/Elo multipliers.
enum EclipseDifficultyPolicy {
    static func limits(rawValue: String, maximumMilliseconds: Int) -> VeilGomokuUnifiedSearch.Limits {
        var result = VeilGomokuUnifiedSearch.Limits()
        let depth: Int, width: Int, nodes: Int, milliseconds: Int, forcing: Int
        switch rawValue {
        case "relaxed":
            (depth, width, nodes, milliseconds, forcing) = (1, 4, 128, 80, 0)
        case "balanced":
            (depth, width, nodes, milliseconds, forcing) = (2, 6, 384, 180, 1)
        case "advanced":
            (depth, width, nodes, milliseconds, forcing) = (3, 8, 1_000, 400, 2)
        case "grandmaster":
            (depth, width, nodes, milliseconds, forcing) = (5, 14, 10_000, 1_900, 4)
        case "legendary":
            (depth, width, nodes, milliseconds, forcing) = (6, 16, 20_000, 3_800, 5)
        case "zenith":
            (depth, width, nodes, milliseconds, forcing) = (7, 18, 30_000, 5_700, 6)
        default:
            // The four current stored difficulties remain compatible. Unknown
            // unknown names fall back to the validated master budget rather
            // than claiming an unmeasured higher strength tier.
            (depth, width, nodes, milliseconds, forcing) = (4, 12, 5_000, 950, 3)
        }
        result.maxDepth = depth
        result.width = width
        result.maxNodes = nodes
        result.maxMilliseconds = max(30, min(milliseconds, maximumMilliseconds))
        result.forcedLineDepth = forcing
        result.candidateRadius = 2
        return result
    }
}
