import Foundation

enum AgentComputeFocus: String, Codable, CaseIterable, Sendable {
    case idle
    case languageChat
    case videoChat
    case gameDecision
    case maleCNSSandbox
    case mediaTransfer

    var title: String {
        switch self {
        case .idle: return "待机"
        case .languageChat: return "本地对话"
        case .videoChat: return "视频对话"
        case .gameDecision: return "游戏决策"
        case .maleCNSSandbox: return "MaleCNS"
        case .mediaTransfer: return "媒体传输"
        }
    }
}

enum A9ComputeMode: String, Codable, CaseIterable, Sendable {
    case boost
    case balanced
    case constrained
    case preserve
    case emergency

    var title: String {
        switch self {
        case .boost: return "BOOST"
        case .balanced: return "BALANCED"
        case .constrained: return "CONSTRAINED"
        case .preserve: return "PRESERVE"
        case .emergency: return "EMERGENCY"
        }
    }
}

enum MaleCNSComputeTier: String, Codable, CaseIterable, Sendable {
    case suspended
    case lite
    case core
    case reference
}

struct MaleCNSComputeBudget: Equatable, Sendable {
    let tier: MaleCNSComputeTier
    let workerCount: Int
    let neuralStepBudget: Int
    let episodeMilliseconds: Int
    let rolloutCount: Int
    let stateSampleStride: Int

    static let suspended = MaleCNSComputeBudget(
        tier: .suspended,
        workerCount: 0,
        neuralStepBudget: 0,
        episodeMilliseconds: 0,
        rolloutCount: 0,
        stateSampleStride: 8
    )
}

struct AgentLanguageComputeBudget: Equatable, Sendable {
    let maxNewTokens: Int
    let recentMessageLimit: Int
    let keepWarm: Bool
}

struct AgentVisionComputeBudget: Equatable, Sendable {
    let enabled: Bool
    let sampleIntervalMilliseconds: Int
    let classificationStride: Int
    let ocrStride: Int
}

struct AgentGameComputeBudget: Equatable, Sendable {
    let plannerMilliseconds: Int
    let searchDepth: Int
    let rolloutCount: Int
    let candidateBatchSize: Int
}

struct AgentTrainingComputeBudget: Equatable, Sendable {
    let enabled: Bool
    let cpuBudgetPercent: Int
    let shardEpisodeLimit: Int
}

struct VeilA9ComputePlan: Equatable, Sendable {
    let mode: A9ComputeMode
    let focus: AgentComputeFocus
    let latticeIndex: Int
    let totalComputeUnits: Int
    let transportReserveUnits: Int
    let maleCNSUnits: Int
    let languageUnits: Int
    let visionUnits: Int
    let gameUnits: Int
    let trainingUnits: Int
    let maleCNS: MaleCNSComputeBudget
    let language: AgentLanguageComputeBudget
    let vision: AgentVisionComputeBudget
    let game: AgentGameComputeBudget
    let training: AgentTrainingComputeBudget

    var optionalComputeUnits: Int {
        maleCNSUnits + languageUnits + visionUnits + gameUnits + trainingUnits
    }

    static func bootstrap(profile: AgentCapabilityProfile) -> VeilA9ComputePlan {
        VeilA9ComputePlanner.plan(
            decision: .initial,
            profile: profile,
            focus: .idle,
            logicalProcessorCount: ProcessInfo.processInfo.activeProcessorCount
        )
    }
}

/// Turns the original 144-state A9 advisory lattice into a deterministic compute budget.
///
/// A9 does not create physical compute. It schedules existing CPU/memory/thermal headroom so
/// MaleCNS, local language, camera Vision, game planning and BLE do not overcommit the device.
/// The output is a budget contract only; each consumer remains responsible for obeying its own
/// safety/game/privacy boundaries.
enum VeilA9ComputePlanner {
    static func plan(
        decision: VeilA9Decision,
        profile: AgentCapabilityProfile,
        focus: AgentComputeFocus,
        logicalProcessorCount: Int,
        foregroundActive: Bool = true,
        allowExperimentalCore: Bool = false
    ) -> VeilA9ComputePlan {
        guard foregroundActive else {
            return backgroundPlan(profile: profile, focus: focus)
        }

        let mode = computeMode(for: decision)
        let deviceUnits = baseUnits(for: profile.tier)
        let safetyPermille = safetyPermille(for: decision.level)
        let healthPermille = max(420, min(1_000, 500 + decision.healthScore * 5))
        let latticePermille = latticeFineTunePermille(index: decision.latticeIndex)
        let gross = deviceUnits * safetyPermille / 1_000 * healthPermille / 1_000 * latticePermille / 1_000

        let transportReserve = transportReserveUnits(
            grossUnits: gross,
            focus: focus,
            issues: decision.issues,
            latticeIndex: decision.latticeIndex
        )
        let available = max(0, gross - transportReserve)
        let shares = workloadShares(focus: focus, mode: mode)

        let maleUnits = available * shares.male / 1_000
        let languageUnits = available * shares.language / 1_000
        let visionUnits = available * shares.vision / 1_000
        let gameUnits = available * shares.game / 1_000
        let assigned = maleUnits + languageUnits + visionUnits + gameUnits
        let trainingUnits = max(0, available - assigned)

        return VeilA9ComputePlan(
            mode: mode,
            focus: focus,
            latticeIndex: decision.latticeIndex,
            totalComputeUnits: gross,
            transportReserveUnits: transportReserve,
            maleCNSUnits: maleUnits,
            languageUnits: languageUnits,
            visionUnits: visionUnits,
            gameUnits: gameUnits,
            trainingUnits: trainingUnits,
            maleCNS: maleCNSBudget(
                units: maleUnits,
                mode: mode,
                profile: profile,
                logicalProcessorCount: logicalProcessorCount,
                allowExperimentalCore: allowExperimentalCore
            ),
            language: languageBudget(units: languageUnits, mode: mode, profile: profile),
            vision: visionBudget(units: visionUnits, mode: mode, profile: profile),
            game: gameBudget(units: gameUnits, mode: mode, profile: profile),
            training: trainingBudget(units: trainingUnits, mode: mode, profile: profile, focus: focus)
        )
    }

    private static func backgroundPlan(
        profile: AgentCapabilityProfile,
        focus: AgentComputeFocus
    ) -> VeilA9ComputePlan {
        let gross = baseUnits(for: profile.tier)
        return VeilA9ComputePlan(
            mode: .preserve,
            focus: focus,
            latticeIndex: 0,
            totalComputeUnits: gross,
            transportReserveUnits: gross,
            maleCNSUnits: 0,
            languageUnits: 0,
            visionUnits: 0,
            gameUnits: 0,
            trainingUnits: 0,
            maleCNS: .suspended,
            language: AgentLanguageComputeBudget(
                maxNewTokens: min(32, profile.maxNewTokens),
                recentMessageLimit: min(4, profile.recentMessageLimit),
                keepWarm: false
            ),
            vision: AgentVisionComputeBudget(
                enabled: false,
                sampleIntervalMilliseconds: 2_400,
                classificationStride: 4,
                ocrStride: 8
            ),
            game: AgentGameComputeBudget(
                plannerMilliseconds: 0,
                searchDepth: 0,
                rolloutCount: 0,
                candidateBatchSize: 0
            ),
            training: AgentTrainingComputeBudget(
                enabled: false,
                cpuBudgetPercent: 0,
                shardEpisodeLimit: 0
            )
        )
    }

    private static func computeMode(for decision: VeilA9Decision) -> A9ComputeMode {
        let issueCodes = Set(decision.issues.map(\.code))
        if issueCodes.contains("THERMAL_CRITICAL") {
            return .emergency
        }
        if issueCodes.contains("THERMAL_SERIOUS") {
            return .preserve
        }

        let base: A9ComputeMode
        switch decision.level {
        case .l0Observe:
            base = decision.healthScore >= 90 ? .boost : .balanced
        case .l1Advisory:
            base = .balanced
        case .l2Review:
            base = .constrained
        case .l3Priority:
            base = .preserve
        case .l4HoldRecommendation, .l5Emergency:
            base = .emergency
        }

        if issueCodes.contains("LOW_POWER_MODE"),
           base == .boost || base == .balanced {
            return .constrained
        }
        return base
    }

    private static func baseUnits(for tier: AgentComputeTier) -> Int {
        switch tier {
        case .legacyA10: return 480
        case .balanced: return 760
        case .high: return 1_000
        }
    }

    private static func safetyPermille(for level: VeilA9Level) -> Int {
        switch level {
        case .l0Observe: return 1_000
        case .l1Advisory: return 880
        case .l2Review: return 680
        case .l3Priority: return 420
        case .l4HoldRecommendation: return 220
        case .l5Emergency: return 120
        }
    }

    private static func latticeFineTunePermille(index: Int) -> Int {
        guard let axes = VeilA9Lattice.axes(for: index) else { return 1_000 }
        if axes.hasP0 { return 700 }
        var value = 1_000
        value -= axes.p1Bucket * 45
        if axes.blocker { value -= 110 }
        if axes.persistent { value -= 55 }
        if axes.redRisk { value -= 90 }
        return max(650, value)
    }

    private static func transportReserveUnits(
        grossUnits: Int,
        focus: AgentComputeFocus,
        issues: [VeilA9Issue],
        latticeIndex: Int
    ) -> Int {
        let codes = Set(issues.map(\.code))
        let axes = VeilA9Lattice.axes(for: latticeIndex)
        var permille = focus == .mediaTransfer ? 420 : 100
        if axes?.blocker == true { permille = max(permille, 500) }
        if axes?.redRisk == true { permille = max(permille, 260) }
        if !codes.isDisjoint(with: ["CONTROL_QUEUE_STALLED", "CONTROL_BACKLOG_HIGH"]) {
            permille = max(permille, 520)
        } else if !codes.isDisjoint(with: ["CONTROL_QUEUE_SLOW", "CONTROL_BACKLOG", "QUEUE_PRESSURE_HIGH"]) {
            permille = max(permille, 360)
        } else if codes.contains("QUEUE_PRESSURE") {
            permille = max(permille, 220)
        }
        return grossUnits * permille / 1_000
    }

    private static func workloadShares(
        focus: AgentComputeFocus,
        mode: A9ComputeMode
    ) -> (male: Int, language: Int, vision: Int, game: Int) {
        if mode == .emergency {
            switch focus {
            case .videoChat: return (80, 520, 260, 40)
            case .languageChat: return (80, 720, 20, 80)
            case .gameDecision: return (220, 120, 0, 560)
            case .maleCNSSandbox: return (620, 100, 0, 180)
            case .mediaTransfer: return (40, 180, 0, 80)
            case .idle: return (80, 120, 0, 80)
            }
        }

        switch focus {
        case .idle:
            return (420, 220, 40, 160)
        case .languageChat:
            return (180, 600, 20, 120)
        case .videoChat:
            return (160, 380, 300, 100)
        case .gameDecision:
            return (360, 100, 0, 460)
        case .maleCNSSandbox:
            return (620, 100, 0, 220)
        case .mediaTransfer:
            return (100, 260, 20, 120)
        }
    }

    private static func maleCNSBudget(
        units: Int,
        mode: A9ComputeMode,
        profile: AgentCapabilityProfile,
        logicalProcessorCount: Int,
        allowExperimentalCore: Bool
    ) -> MaleCNSComputeBudget {
        guard mode != .emergency, units >= 60 else { return .suspended }

        let workerCap: Int
        switch profile.tier {
        case .legacyA10: workerCap = 2
        case .balanced: workerCap = 3
        case .high: workerCap = 4
        }
        let workers = max(1, min(workerCap, max(1, logicalProcessorCount - 2)))

        if allowExperimentalCore,
           units >= 360,
           profile.tier == .high,
           mode == .boost {
            return MaleCNSComputeBudget(
                tier: .core,
                workerCount: workers,
                neuralStepBudget: 180,
                episodeMilliseconds: 420,
                rolloutCount: 8,
                stateSampleStride: 1
            )
        }
        if allowExperimentalCore,
           units >= 210,
           profile.tier != .legacyA10 {
            return MaleCNSComputeBudget(
                tier: .core,
                workerCount: workers,
                neuralStepBudget: 110,
                episodeMilliseconds: 280,
                rolloutCount: 4,
                stateSampleStride: 2
            )
        }
        return MaleCNSComputeBudget(
            tier: .lite,
            workerCount: min(workers, profile.tier == .legacyA10 ? 1 : 2),
            neuralStepBudget: max(28, min(84, units / 3)),
            episodeMilliseconds: max(90, min(220, units)),
            rolloutCount: units >= 140 ? 2 : 1,
            stateSampleStride: units >= 160 ? 2 : 4
        )
    }

    private static func languageBudget(
        units: Int,
        mode: A9ComputeMode,
        profile: AgentCapabilityProfile
    ) -> AgentLanguageComputeBudget {
        let floorTokens = 32
        let scaled = max(floorTokens, min(profile.maxNewTokens, units / 2 + 24))
        let recent = max(4, min(profile.recentMessageLimit, units / 24 + 4))
        return AgentLanguageComputeBudget(
            maxNewTokens: scaled,
            recentMessageLimit: recent,
            keepWarm: mode == .boost && profile.tier != .legacyA10
        )
    }

    private static func visionBudget(
        units: Int,
        mode: A9ComputeMode,
        profile: AgentCapabilityProfile
    ) -> AgentVisionComputeBudget {
        guard units >= 35, mode != .emergency else {
            return AgentVisionComputeBudget(
                enabled: units >= 45,
                sampleIntervalMilliseconds: 2_400,
                classificationStride: 4,
                ocrStride: 8
            )
        }
        switch profile.tier {
        case .legacyA10:
            return AgentVisionComputeBudget(
                enabled: true,
                sampleIntervalMilliseconds: units >= 100 ? 1_450 : 2_000,
                classificationStride: units >= 100 ? 2 : 3,
                ocrStride: units >= 100 ? 4 : 6
            )
        case .balanced:
            return AgentVisionComputeBudget(
                enabled: true,
                sampleIntervalMilliseconds: units >= 140 ? 760 : 1_150,
                classificationStride: 1,
                ocrStride: units >= 140 ? 2 : 3
            )
        case .high:
            return AgentVisionComputeBudget(
                enabled: true,
                sampleIntervalMilliseconds: units >= 180 ? 360 : 650,
                classificationStride: 1,
                ocrStride: units >= 180 ? 1 : 2
            )
        }
    }

    private static func gameBudget(
        units: Int,
        mode: A9ComputeMode,
        profile: AgentCapabilityProfile
    ) -> AgentGameComputeBudget {
        let depth: Int
        if mode == .emergency || units < 80 { depth = 0 }
        else if units < 220 || profile.tier == .legacyA10 { depth = 1 }
        else { depth = 2 }
        return AgentGameComputeBudget(
            plannerMilliseconds: max(18, min(320, units)),
            searchDepth: depth,
            rolloutCount: max(1, min(12, units / 55)),
            candidateBatchSize: max(8, min(96, units / 4))
        )
    }

    private static func trainingBudget(
        units: Int,
        mode: A9ComputeMode,
        profile: AgentCapabilityProfile,
        focus: AgentComputeFocus
    ) -> AgentTrainingComputeBudget {
        let enabled = focus == .idle && mode == .boost && profile.tier == .high && units >= 80
        return AgentTrainingComputeBudget(
            enabled: enabled,
            cpuBudgetPercent: enabled ? min(28, max(8, units / 8)) : 0,
            shardEpisodeLimit: enabled ? min(24, max(4, units / 16)) : 0
        )
    }
}
