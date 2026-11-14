import Foundation

/// R15 EXPERIMENTAL: preserve the selected elapsed-time budget, no hidden 80/180/400ms clamp.
/// Passing maximumMilliseconds <= 0 means no wall-clock deadline; node+depth caps remain.
enum EclipseDifficultyPolicy {
    static func limits(rawValue: String, maximumMilliseconds: Int) -> VeilGomokuUnifiedSearch.Limits {
        var r = VeilGomokuUnifiedSearch.Limits()
        switch rawValue {
        case "relaxed":
            (r.maxDepth, r.width, r.maxNodes, r.forcedLineDepth) = (1, 4, 256, 0)
        case "balanced":
            (r.maxDepth, r.width, r.maxNodes, r.forcedLineDepth) = (3, 8, 2_500, 2)
        case "advanced":
            (r.maxDepth, r.width, r.maxNodes, r.forcedLineDepth) = (4, 12, 6_500, 3)
        case "grandmaster":
            (r.maxDepth, r.width, r.maxNodes, r.forcedLineDepth) = (6, 18, 60_000, 6)
        case "legendary":
            (r.maxDepth, r.width, r.maxNodes, r.forcedLineDepth) = (7, 20, 140_000, 7)
        case "zenith":
            (r.maxDepth, r.width, r.maxNodes, r.forcedLineDepth) = (8, 24, 350_000, 8)
        default:
            (r.maxDepth, r.width, r.maxNodes, r.forcedLineDepth) = (5, 16, 20_000, 4)
        }
        r.maxMilliseconds = maximumMilliseconds <= 0 ? 0 : max(30, maximumMilliseconds)
        r.candidateRadius = 2
        // R12 prevents static evaluation of a leaf with an exact four/five emergency.
        // Remains an experimental policy until paired-match acceptance.
        r.r12HorizonQuiescence = r.maxDepth >= 4
        r.r12MaxForcedBlocks = 2
        // R13 remains OFF until exact index differential tests are completed.
        r.r13IncrementalThreatIndexEnabled = false
        return r
    }
}


/// R16 local experimental controls. Stored separately from saved matches,
/// learning archives, difficulty and other games.
enum EclipseThinkingMode: String, CaseIterable, Codable, Sendable {
    case automatic
    case custom
    case untimed
}

struct EclipseAdvancedOptions: Equatable, Sendable {
    static let storagePrefix = "VeilLink.Gomoku.EclipseAdvanced.v1."

    var thinkingMode: EclipseThinkingMode = .automatic
    var seconds: Int = 30
    // R12 was validated in R15's tactical regressions; enable for every tier.
    var r12Enabled: Bool = true
    // R13 exact-threat index has differential correctness evidence, but limited
    // full-game performance/thermal evidence. Let the player opt in explicitly.
    var r13Enabled: Bool = false
    var maxNodes: Int = 350_000
    var maxDepth: Int = 8

    static func load(from store: UserDefaults = .standard) -> Self {
        let prefix = storagePrefix
        let raw = store.string(forKey: prefix + "thinkingMode") ?? "automatic"
        let t = EclipseThinkingMode(rawValue: raw) ?? .automatic
        let seconds = store.object(forKey: prefix + "seconds") == nil ? 30
            : store.integer(forKey: prefix + "seconds")
        let r12 = store.object(forKey: prefix + "r12Enabled") == nil ? true
            : store.bool(forKey: prefix + "r12Enabled")
        let r13 = store.bool(forKey: prefix + "r13Enabled")
        let nodes = store.object(forKey: prefix + "maxNodes") == nil ? 350_000
            : store.integer(forKey: prefix + "maxNodes")
        let depth = store.object(forKey: prefix + "maxDepth") == nil ? 8
            : store.integer(forKey: prefix + "maxDepth")
        return Self(thinkingMode: t,
                    seconds: max(5, min(300, seconds)),
                    r12Enabled: r12,
                    r13Enabled: r13,
                    maxNodes: max(50_000, min(2_000_000, nodes)),
                    maxDepth: max(3, min(12, depth)))
    }

    func save(to store: UserDefaults = .standard) {
        let prefix = Self.storagePrefix
        store.set(thinkingMode.rawValue, forKey: prefix + "thinkingMode")
        store.set(seconds, forKey: prefix + "seconds")
        store.set(r12Enabled, forKey: prefix + "r12Enabled")
        store.set(r13Enabled, forKey: prefix + "r13Enabled")
        store.set(maxNodes, forKey: prefix + "maxNodes")
        store.set(maxDepth, forKey: prefix + "maxDepth")
    }

    func applying(to budget: GomokuBotBudget) -> GomokuBotBudget {
        let time: Int
        switch thinkingMode {
        case .automatic: time = budget.timeLimitMilliseconds
        case .custom: time = max(5, min(300, seconds)) * 1_000
        case .untimed: time = 0
        }
        return GomokuBotBudget(
            candidateRadius: budget.candidateRadius,
            rootCandidateLimit: budget.rootCandidateLimit,
            replyCandidateLimit: budget.replyCandidateLimit,
            continuationCandidateLimit: budget.continuationCandidateLimit,
            timeLimitMilliseconds: time
        )
    }

    func applying(to limits: inout VeilGomokuUnifiedSearch.Limits) {
        limits.r12HorizonQuiescence = r12Enabled
        limits.r13IncrementalThreatIndexEnabled = r13Enabled
        if thinkingMode != .automatic {
            limits.maxNodes = max(50_000, min(2_000_000, maxNodes))
            limits.maxDepth = max(3, min(12, maxDepth))
        }
    }
}
