import Combine
import Foundation

enum VeilKernelRuntimeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case a9Only = "A9_ONLY"
    case dualShadow = "A9_PLUS_A10_ULTRA_SHADOW"
    case a10Independent = "A10_ULTRA_INDEPENDENT_GOVERNANCE"
    case a10OnlyLab = "A10_ULTRA_ONLY_LAB"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .a9Only: return "仅 A9"
        case .dualShadow: return "A9 + A10 Ultra Ω"
        case .a10Independent: return "A10 Ultra Ω · 独立治理"
        case .a10OnlyLab: return "仅 A10 Ultra Ω · 实验"
        }
    }

    var detail: String {
        switch self {
        case .a9Only:
            return "只运行 A9 Health Lattice / Compute Governor，作为生产基线。"
        case .dualShadow:
            return "A9 保持 PRIMARY；A10 Ultra Ω 以 SHADOW_ACCELERATOR 同样本并行运行。"
        case .a10Independent:
            return "A10 Ultra Ω 独立完成健康裁决并正式生成算力预算；运行失败时由宿主立即回退 A9。"
        case .a10OnlyLab:
            return "只运行 A10 Ultra Ω 健康裁决；A9 本轮不计算，宿主冻结进入实验前的安全预算。仅用于本机实验，不能视为 Cutover。"
        }
    }

    var a9EvaluationEnabled: Bool {
        self != .a10Independent && self != .a10OnlyLab
    }

    var ultraEvaluationEnabled: Bool {
        self != .a9Only
    }

    var productionAuthority: String {
        switch self {
        case .a9Only, .dualShadow: return "A9_PRIMARY"
        case .a10Independent: return "A10_ULTRA_GOVERNANCE"
        case .a10OnlyLab: return "HOST_FROZEN_BASELINE"
        }
    }

    var fallbackPolicy: String {
        switch self {
        case .a9Only: return "A9_LOCAL"
        case .dualShadow: return "A9_IMMEDIATE"
        case .a10Independent: return "AUTO_FALLBACK_TO_A9_ON_ULTRA_FAILURE"
        case .a10OnlyLab: return "AUTO_EXIT_TO_A9_ON_ULTRA_FAILURE_OR_RESTART"
        }
    }

    var isExperimental: Bool { self == .a10OnlyLab }

    var productionCutover: String {
        self == .a10Independent ? "GOVERNANCE_ONLY_APPROVED" : "DENIED"
    }
}

struct VeilKernelRuntimeEnvironment: Equatable, Sendable {
    let mode: VeilKernelRuntimeMode
    let modeEpoch: UInt64
    let modeSessionID: String
    let modeSampleOrdinal: UInt64
    let enteredAt: Date
    let selectionSource: String
    let productionAuthority: String
    let fallbackPolicy: String
    let a9EvaluationEnabled: Bool
    let ultraEvaluationEnabled: Bool
    let mutationAuthority: Int
    let productionCutover: String
}

struct VeilKernelRuntimeSampleRecord: Equatable, Sendable {
    let sampleID: String
    let epoch: UInt64
    let timestamp: Date
    let sourceDomains: [String]
    let signalDigest: String
    let environment: VeilKernelRuntimeEnvironment
    let a9Decision: VeilKernelDecisionSnapshot?
    let ultraDecision: VeilKernelDecisionSnapshot?
    let a9Budget: VeilKernelComputeBudgetEnvelope?
    let ultraBudget: A10UltraOmegaBudget?
    let decisionMatch: Bool?
    let divergenceClass: String
    let a9LatencyNanos: UInt64
    let ultraLatencyNanos: UInt64
    let a9CPUNanos: UInt64
    let ultraCPUNanos: UInt64
    let ultraPhysicalSlotCount: Int
    let rssBytes: UInt64
    let thermalState: Int
    let batteryPermille: Int
    let energyProxy: UInt64
    let bleState: String
    let queueDepth: Int
    let droppedEventCount: Int
    let ultraRestartCount: Int
    let fallbackEvent: Bool
    let guardianStatus: String
    let rageStatus: String
    let vaultStatus: String
    let runtimeBackend: String
}

@MainActor
final class VeilKernelRuntimeSelector: ObservableObject {
    static let stableModeKey = "kernel.runtime.stable_mode.v1"
    static let labActiveKey = "kernel.runtime.lab_active.v1"

    @Published private(set) var mode: VeilKernelRuntimeMode
    @Published private(set) var modeEpoch: UInt64 = 1
    @Published private(set) var modeSessionID = UUID().uuidString
    @Published private(set) var enteredAt = Date()
    @Published private(set) var selectionSource = "BOOT"
    @Published private(set) var currentModeSampleCount: UInt64 = 0
    @Published private(set) var lastFallbackReason: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.stableModeKey).flatMap(VeilKernelRuntimeMode.init(rawValue:))
        // A10-only LAB never survives a process restart. Persist only a one-bit crash/restart
        // sentinel so the next launch can prove the environment exited to A9, not silently resume.
        if defaults.bool(forKey: Self.labActiveKey) {
            mode = .a9Only
            lastFallbackReason = "LAB_MODE_RESTART_FALLBACK"
            defaults.set(false, forKey: Self.labActiveKey)
            defaults.set(VeilKernelRuntimeMode.a9Only.rawValue, forKey: Self.stableModeKey)
        } else {
            mode = saved ?? .a10Independent
        }
    }

    func select(_ requested: VeilKernelRuntimeMode, source: String = "USER") {
        guard requested != mode else { return }
        mode = requested
        modeEpoch &+= 1
        modeSessionID = UUID().uuidString
        enteredAt = Date()
        selectionSource = source
        currentModeSampleCount = 0
        lastFallbackReason = nil
        // Persist stable modes only. LAB writes a one-bit restart sentinel, never a resumable mode.
        if requested.isExperimental {
            defaults.set(true, forKey: Self.labActiveKey)
        } else {
            defaults.set(false, forKey: Self.labActiveKey)
            defaults.set(requested.rawValue, forKey: Self.stableModeKey)
        }
    }

    func forceA9Fallback(reason: String) {
        lastFallbackReason = reason
        mode = .a9Only
        modeEpoch &+= 1
        modeSessionID = UUID().uuidString
        enteredAt = Date()
        selectionSource = "AUTO_FALLBACK"
        currentModeSampleCount = 0
        defaults.set(false, forKey: Self.labActiveKey)
        defaults.set(VeilKernelRuntimeMode.a9Only.rawValue, forKey: Self.stableModeKey)
    }

    func beginSample() -> VeilKernelRuntimeEnvironment {
        currentModeSampleCount &+= 1
        return VeilKernelRuntimeEnvironment(
            mode: mode,
            modeEpoch: modeEpoch,
            modeSessionID: modeSessionID,
            modeSampleOrdinal: currentModeSampleCount,
            enteredAt: enteredAt,
            selectionSource: selectionSource,
            productionAuthority: mode.productionAuthority,
            fallbackPolicy: mode.fallbackPolicy,
            a9EvaluationEnabled: mode.a9EvaluationEnabled,
            ultraEvaluationEnabled: mode.ultraEvaluationEnabled,
            mutationAuthority: 0,
            productionCutover: mode.productionCutover
        )
    }

    func snapshot() -> VeilKernelRuntimeEnvironment {
        VeilKernelRuntimeEnvironment(
            mode: mode,
            modeEpoch: modeEpoch,
            modeSessionID: modeSessionID,
            modeSampleOrdinal: currentModeSampleCount,
            enteredAt: enteredAt,
            selectionSource: selectionSource,
            productionAuthority: mode.productionAuthority,
            fallbackPolicy: mode.fallbackPolicy,
            a9EvaluationEnabled: mode.a9EvaluationEnabled,
            ultraEvaluationEnabled: mode.ultraEvaluationEnabled,
            mutationAuthority: 0,
            productionCutover: mode.productionCutover
        )
    }

    func report() -> String {
        [
            "VeilLink Kernel Runtime Selector",
            "Mode: \(mode.rawValue) · \(mode.title)",
            "Mode epoch: \(modeEpoch)",
            "Mode session: \(modeSessionID)",
            "Samples in mode: \(currentModeSampleCount)",
            "Selection source: \(selectionSource)",
            "Production authority: \(mode.productionAuthority)",
            "A9 evaluation: \(mode.a9EvaluationEnabled ? "enabled" : "disabled")",
            "A10 Ultra Ω evaluation: \(mode.ultraEvaluationEnabled ? "enabled" : "disabled")",
            "Fallback: \(mode.fallbackPolicy)",
            "Last fallback reason: \(lastFallbackReason ?? "none")",
            "Mutation authority: 0",
            "PRODUCTION_CUTOVER: \(mode.productionCutover)",
            "Boundary: governance-only; M5 inference and app mutation authority are not promoted"
        ].joined(separator: "\n")
    }
}
