import Combine
import CryptoKit
import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(Glibc)
import Glibc
#endif
#if canImport(UIKit)
import UIKit
#endif

/// A10 Ultra Ω is the chip name. OMEGA 96 V0.2 is the currently loaded shadow execution architecture.
enum A10UltraOmegaRelease {
    static let chipName = "A10 Ultra Ω"
    static let architecture = "OMEGA 96"
    static let architectureVersion = "V0.2"
    static let releaseStatus = "SHADOW_ACCELERATED"
    static let productionCutover = "DENIED"
    static let componentID = "A10-ULTRA-OMEGA-96"
    static let decisionLUTSHA256 = "1be3dd04ee99df8d12c56035982fe1d29dcc1847997718a0e9df5903ae11d640"
    static let sourceSHA256 = "75fa59e9e59de8d007f418a5ebf1f912dfa4fc461ea0b36eaf40509e7960c3bb"
    static let linuxBinarySHA256 = "332b60aabe72a6dfdddee05e45ff7907f6627a92356ee7f8396a84de6e6741f8"
    static let sourcePackageSHA256 = "a5fbcae6484f2ce4a05a27fb7c90009fd9137f241bdc16241a22c2b37fb3f258"
    static let nativeIOSARM64Available = false
    static let runtimeBackend = "SWIFT_REFERENCE_A9_COMPAT"
    static let nativeBackendLimitation = "OMEGA96 V0.2 native artifact is CPython 3.13 x86_64 Linux; iOS arm64 universal native runner not supplied."
}

enum A10UltraOmegaCutoverStage: String, Codable, Sendable {
    case stage0 = "STAGE_0_A9_PRIMARY_ULTRA_SHADOW"
    case stage1 = "STAGE_1_ULTRA_PRIMARY_CANARY_A9_IMMEDIATE_FALLBACK"
    case stage2 = "STAGE_2_ULTRA_PRIMARY_A9_HOT_STANDBY"
    case stage3 = "STAGE_3_ULTRA_PRIMARY_A9_COLD_FALLBACK"
    case stage4 = "STAGE_4_ULTRA_ONLY"
}

enum A10UltraOmegaTestPhase: String, Codable, Sendable {
    case passive = "PHASE_A_PASSIVE_SHADOW"
    case stress = "PHASE_B_STRESS"
    case faultInjection = "PHASE_C_FAULT_INJECTION"
    case soak = "PHASE_D_SOAK"
}

enum A10UltraOmegaDivergenceClass: String, Codable, Sendable {
    case d0 = "D0_EXACT_MATCH"
    case d1 = "D1_EXPECTED_EXTENSION"
    case d2 = "D2_NON_SAFETY_DIFFERENCE"
    case d3 = "D3_SAFETY_RELEVANT_DIFFERENCE"
    case d4 = "D4_CRITICAL_FALSE_NEGATIVE"
    case d5 = "D5_ULTRA_INTERNAL_FAILURE"
}

struct A10UltraOmegaHostContext: Equatable, Sendable {
    // Raw host facts only. Never place A9 Decision / Compute Plan outputs in this structure.
    let foregroundActive: Bool
    let systemAvailable: Bool
    let gameRuntimeState: String
    let activeProcessorCount: Int
    let physicalMemoryBytes: UInt64
}

struct A10UltraOmegaSharedSample: Equatable, Sendable {
    let sampleID: String
    let epoch: UInt64
    let timestamp: Date
    let uptime: TimeInterval
    let sourceDomains: [String]
    let signalDigest: String
    let rawInput: VeilA9Input
    let hostContext: A10UltraOmegaHostContext
}

struct A10UltraOmegaBudget: Equatable, Sendable {
    let mode: String
    let cpuPct: Int
    let workerPct: Int
    let languagePct: Int
    let visionPct: Int
    let gamePct: Int
    let trainingPct: Int
    let transportReservePct: Int
    let storageRecoveryReservePct: Int

    static func forAuthority(_ authority: Int, foreground: Bool) -> A10UltraOmegaBudget {
        let rank = max(0, min(5, authority))
        let base: (String, Int, Int, Int, Int, Int, Int, Int, Int)
        switch rank {
        case 0: base = ("NORMAL", 100, 100, 100, 100, 100, 60, 20, 20)
        case 1: base = ("GUARDED", 90, 90, 90, 85, 85, 40, 25, 25)
        case 2: base = ("CONSTRAINED", 75, 70, 75, 60, 60, 20, 35, 30)
        case 3: base = ("PRIORITY_STABILITY", 60, 55, 60, 40, 45, 10, 45, 40)
        case 4: base = ("HOLD_BACKGROUND", 45, 35, 45, 20, 30, 0, 55, 50)
        default: base = ("EMERGENCY_RESERVE", 30, 20, 30, 0, 15, 0, 65, 60)
        }
        let language = foreground && rank <= 3 ? min(100, base.3 + 5) : base.3
        let game = foreground && rank <= 3 ? min(100, base.5 + 5) : base.5
        return A10UltraOmegaBudget(
            mode: base.0, cpuPct: base.1, workerPct: base.2, languagePct: language,
            visionPct: base.4, gamePct: game, trainingPct: base.6,
            transportReservePct: base.7, storageRecoveryReservePct: base.8
        )
    }
}

struct A10UltraOmegaShadowDecision: Equatable, Sendable {
    let compatibilityDecision: VeilKernelDecisionSnapshot
    let budget: A10UltraOmegaBudget
    let preflight: String
    let faultDomain: String
    let backend: String
    let physicalSlotCount: Int
    let guardianStatus: String
    let rageStatus: String
    let vaultStatus: String
}

struct A10UltraOmegaGovernanceResult: Equatable, Sendable {
    let decision: VeilKernelDecisionSnapshot
    let budget: A10UltraOmegaBudget
}

struct A10UltraOmegaComparisonRecord: Equatable, Sendable {
    let sampleID: String
    let epoch: UInt64
    let timestamp: Date
    let uptime: TimeInterval
    let sourceDomains: [String]
    let signalDigest: String
    let a9: VeilKernelDecisionSnapshot
    let ultra: VeilKernelDecisionSnapshot?
    let a9Budget: VeilKernelComputeBudgetEnvelope
    let ultraBudget: A10UltraOmegaBudget?
    let decisionMatch: Bool
    let divergence: A10UltraOmegaDivergenceClass
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
    let nativeIOSARM64Available: Bool
}

struct A10UltraOmegaShadowState: Equatable, Sendable {
    let cutoverStage: A10UltraOmegaCutoverStage
    let testPhase: A10UltraOmegaTestPhase
    let validSharedSamples: UInt64
    let exactMatches: UInt64
    let d1Count: UInt64
    let d2Count: UInt64
    let d3Count: UInt64
    let d4Count: UInt64
    let d5Count: UInt64
    let droppedEventCount: Int
    let fallbackEventCount: UInt64
    let productionCutover: String

    static let initial = A10UltraOmegaShadowState(
        cutoverStage: .stage0,
        testPhase: .passive,
        validSharedSamples: 0,
        exactMatches: 0,
        d1Count: 0,
        d2Count: 0,
        d3Count: 0,
        d4Count: 0,
        d5Count: 0,
        droppedEventCount: 0,
        fallbackEventCount: 0,
        productionCutover: "DENIED"
    )
}

private struct A10UltraOmegaCompatAggregate: Sendable {
    let light: Int
    let p0: Int
    let p1: Int
    let p2: Int
    let p3: Int
    let riskBP: Int
    let healthBP: Int
    let persistenceSeconds: Int
    let compatPersistenceRuns: Int
    let blocker: Bool
    let issues: [VeilKernelIssueSnapshot]
}

/// Independent raw-host normalizer. It intentionally does not call VeilA9Classifier or consume an A9 Decision.
private enum A10UltraOmegaCompatibilityNormalizer {
    static func aggregate(_ input: VeilA9Input, persistenceSeconds: Int) -> A10UltraOmegaCompatAggregate {
        var issues: [VeilKernelIssueSnapshot] = []
        func add(_ severity: String, _ source: String, _ code: String) {
            issues.append(VeilKernelIssueSnapshot(severity: severity, source: source, code: code))
        }

        if input.databaseIntegrity == .failed {
            add("P0", "storage", "SQLITE_INTEGRITY_FAILED")
        }
        if input.maximumStallMilliseconds >= 20_000 && input.controlPendingPackets > 0 {
            add("P1", "ble", "CONTROL_QUEUE_STALLED")
        } else if input.maximumStallMilliseconds >= 8_000 && input.controlPendingPackets > 0 {
            add("P2", "ble", "CONTROL_QUEUE_SLOW")
        }
        if input.maximumReconnectAttempt >= 6 && input.recoveringPeerCount > 0 {
            add("P1", "ble", "RECONNECT_PERSISTENT")
        } else if input.maximumReconnectAttempt >= 3 && input.recoveringPeerCount > 0 {
            add("P2", "ble", "RECONNECT_REPEATED")
        } else if input.recoveringPeerCount > 0 {
            add("P3", "ble", "RECONNECT_ACTIVE")
        }
        if input.controlPendingPackets >= 64 {
            add("P1", "ble", "CONTROL_BACKLOG_HIGH")
        } else if input.controlPendingPackets >= 16 {
            add("P2", "ble", "CONTROL_BACKLOG")
        }
        if input.pendingBytes >= 2 * 1_024 * 1_024 {
            add("P2", "ble", "QUEUE_PRESSURE_HIGH")
        } else if input.pendingBytes >= 512 * 1_024 {
            add("P3", "ble", "QUEUE_PRESSURE")
        }
        if input.weakPeerCount > 0 {
            add("P2", "ble", "WEAK_LINK")
        } else if input.marginalPeerCount > 0 {
            add("P3", "ble", "MARGINAL_LINK")
        }
        if let minimumLinkHealth = input.minimumLinkHealth, minimumLinkHealth < 30 {
            add("P2", "ble", "LINK_HEALTH_LOW")
        }
        if input.agentUnavailable && input.agentHasFailure {
            add("P2", "agent", "AGENT_RUNTIME_FAILED")
        } else if input.agentUnavailable {
            add("P3", "agent", "AGENT_RUNTIME_UNAVAILABLE")
        } else if input.agentCooling {
            add("P3", "agent", "AGENT_RUNTIME_LIMITED")
        }
        switch input.thermalLevel {
        case .critical: add("P1", "system", "THERMAL_CRITICAL")
        case .serious: add("P2", "system", "THERMAL_SERIOUS")
        case .fair: add("P3", "system", "THERMAL_FAIR")
        case .nominal: break
        }
        if input.lowPowerMode { add("P3", "system", "LOW_POWER_MODE") }

        let p0 = issues.filter { $0.severity == "P0" }.count
        let p1 = issues.filter { $0.severity == "P1" }.count
        let p2 = issues.filter { $0.severity == "P2" }.count
        let p3 = issues.filter { $0.severity == "P3" }.count
        let riskBP = (p0 * 40 + p1 * 12 + p2 * 4 + p3) * 100
        let healthBP = max(0, 1_000 - p0 * 500 - p1 * 160 - p2 * 70 - p3 * 20)
        let blocker = p0 > 0 || (input.maximumStallMilliseconds >= 20_000 && input.controlPendingPackets > 0)
        let light: Int
        if p0 > 0 || riskBP >= 2_800 || healthBP < 500 {
            light = 2
        } else if !issues.isEmpty || healthBP < 800 {
            light = 1
        } else {
            light = 0
        }
        // OMEGA V0.2's DBHealth-compatible frame retains the historical >=3 run bit. VeilLink I4
        // uses monotonic seconds, so the Host Adapter maps the shared safety threshold (30 s) to
        // the compatibility threshold without feeding an A9 Decision into A10 Ultra Ω.
        let compatRuns = persistenceSeconds >= VeilA9Lattice.persistentDurationThresholdSeconds ? 3 : 0
        return A10UltraOmegaCompatAggregate(
            light: light, p0: p0, p1: p1, p2: p2, p3: p3,
            riskBP: riskBP, healthBP: healthBP, persistenceSeconds: persistenceSeconds,
            compatPersistenceRuns: compatRuns, blocker: blocker,
            issues: issues.sorted {
                if $0.severity != $1.severity { return $0.severity < $1.severity }
                if $0.source != $1.source { return $0.source < $1.source }
                return $0.code < $1.code
            }
        )
    }
}

private enum A10UltraOmegaDecisionCore {
    static func decide(_ aggregate: A10UltraOmegaCompatAggregate) -> VeilKernelDecisionSnapshot {
        var effectiveLight = aggregate.light
        if aggregate.p0 > 0 || aggregate.riskBP >= 2_800 || aggregate.healthBP < 500 {
            effectiveLight = 2
        } else if aggregate.p0 + aggregate.p1 + aggregate.p2 + aggregate.p3 > 0 || aggregate.healthBP < 800 {
            effectiveLight = max(effectiveLight, 1)
        }
        let p1Bucket = aggregate.p1 <= 0 ? 0 : (aggregate.p1 == 1 ? 1 : 2)
        let persistent = aggregate.compatPersistenceRuns >= 3
        let riskRed = aggregate.riskBP >= 2_800
        var authority: Int
        var reason: String
        if aggregate.p0 > 0 {
            authority = 5; reason = "P0_HARD_BREAK"
        } else if effectiveLight == 2 && aggregate.blocker {
            authority = 4; reason = "RED_WITH_BLOCKER"
        } else if effectiveLight == 2 {
            authority = 3; reason = "RED_NO_BLOCKER"
        } else if effectiveLight == 1 && (p1Bucket > 0 || persistent) {
            authority = 2; reason = "YELLOW_PERSISTENT_OR_P1"
        } else if effectiveLight == 1 {
            authority = 1; reason = "YELLOW_ADVISORY"
        } else {
            authority = 0; reason = "GREEN_NORMAL"
        }
        let floor = aggregate.p0 > 0 ? 5 : ((aggregate.blocker && effectiveLight == 2) ? 4 : ((p1Bucket >= 2 || riskRed) ? 3 : 0))
        if authority < floor { authority = floor; reason = "SAFETY_FLOOR_OVERRIDE" }
        let latticeIndex = effectiveLight
            + 3 * (aggregate.p0 > 0 ? 1 : 0)
            + 6 * p1Bucket
            + 18 * (aggregate.blocker ? 1 : 0)
            + 36 * (persistent ? 1 : 0)
            + 72 * (riskRed ? 1 : 0)
        let lightTitle = effectiveLight == 2 ? "红色" : (effectiveLight == 1 ? "黄色" : "绿色")
        let preflight: VeilKernelPreflightRecommendation = aggregate.p0 > 0 ? .stopRecommended : (effectiveLight == 0 ? .proceed : .review)
        return VeilKernelDecisionSnapshot(
            profileID: VeilKernelHostProfile.veilLink.compatibilityProfileID,
            light: lightTitle,
            level: authority,
            reasonCode: reason,
            healthScore: max(0, min(100, aggregate.healthBP / 10)),
            riskBasisPoints: aggregate.riskBP,
            persistenceSeconds: aggregate.persistenceSeconds,
            latticeCell: latticeIndex,
            issues: aggregate.issues,
            preflight: preflight
        )
    }
}

private struct A10UltraOmegaSwiftReferenceRunner {
    func evaluate(_ sample: A10UltraOmegaSharedSample, persistenceSeconds: Int) throws -> A10UltraOmegaShadowDecision {
        let aggregate = A10UltraOmegaCompatibilityNormalizer.aggregate(sample.rawInput, persistenceSeconds: persistenceSeconds)
        let decision = A10UltraOmegaDecisionCore.decide(aggregate)
        let budget = A10UltraOmegaBudget.forAuthority(decision.level, foreground: sample.hostContext.foregroundActive)
        let preflight: String
        if decision.level >= 4 { preflight = "HOLD" }
        else if decision.level >= 2 { preflight = "REVIEW" }
        else { preflight = "PROCEED" }
        let faultDomain = aggregate.issues.first?.source ?? "none"
        return A10UltraOmegaShadowDecision(
            compatibilityDecision: decision,
            budget: budget,
            preflight: preflight,
            faultDomain: faultDomain,
            backend: A10UltraOmegaRelease.runtimeBackend,
            physicalSlotCount: 1,
            guardianStatus: "REFERENCE_CONTRACT_ONLY",
            rageStatus: "REFERENCE_CONTRACT_ONLY",
            vaultStatus: "REFERENCE_NON_PERSISTENT"
        )
    }
}

private enum A10UltraOmegaMetrics {
    static func monotonicNanos() -> UInt64 {
        UInt64(max(0, ProcessInfo.processInfo.systemUptime * 1_000_000_000))
    }

    static func threadCPUNanos() -> UInt64 {
        var ts = timespec()
        #if canImport(Darwin) || canImport(Glibc)
        if clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts) == 0 {
            return UInt64(max(0, ts.tv_sec)) * 1_000_000_000 + UInt64(max(0, ts.tv_nsec))
        }
        #endif
        return 0
    }

    static func rssBytes() -> UInt64 {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
        #else
        return 0
        #endif
    }

    static func batteryPermille() -> Int {
        #if canImport(UIKit)
        let value = UIDevice.current.batteryLevel
        return value < 0 ? -1 : Int((value * 1_000).rounded())
        #else
        return -1
        #endif
    }
}

@MainActor
final class A10UltraOmegaShadowCoordinator: ObservableObject {
    @Published private(set) var state = A10UltraOmegaShadowState.initial
    @Published private(set) var lastComparison: A10UltraOmegaComparisonRecord?
    @Published private(set) var lastRuntimeSample: VeilKernelRuntimeSampleRecord?
    @Published private(set) var isolatedSampleCount: UInt64 = 0
    @Published private(set) var runtimeEpochResetCount: UInt64 = 0
    @Published private(set) var lastRuntimeEpochResetReason = "BOOT"

    private var epoch: UInt64 = 0
    private var ultraNonGreenSinceUptime: TimeInterval?
    private var pendingA9: (sampleID: String, decision: VeilKernelDecisionSnapshot, budget: VeilKernelComputeBudgetEnvelope, latency: UInt64, cpu: UInt64)?
    private let runner = A10UltraOmegaSwiftReferenceRunner()

    /// Runtime-mode boundaries are measurement boundaries. Persistence and pending A9 pairing
    /// must never leak across A9-only / Dual / A10-only experiments.
    func resetRuntimeEpoch(reason: String) {
        pendingA9 = nil
        ultraNonGreenSinceUptime = nil
        runtimeEpochResetCount &+= 1
        lastRuntimeEpochResetReason = reason
    }

    func makeSharedSample(input: VeilA9Input, hostContext: A10UltraOmegaHostContext) -> A10UltraOmegaSharedSample {
        epoch &+= 1
        let timestamp = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        let sampleID = UUID().uuidString
        let domains = ["transport", "storage", "system", "agent", "game", "compute", "lifecycle"]
        let digest = Self.signalDigest(input: input, context: hostContext, epoch: epoch, timestamp: timestamp)
        return A10UltraOmegaSharedSample(
            sampleID: sampleID,
            epoch: epoch,
            timestamp: timestamp,
            uptime: uptime,
            sourceDomains: domains,
            signalDigest: digest,
            rawInput: input,
            hostContext: hostContext
        )
    }

    func recordA9Primary(
        sample: A10UltraOmegaSharedSample,
        decision: VeilA9Decision,
        budget: VeilA9ComputePlan,
        latencyNanos: UInt64,
        cpuNanos: UInt64
    ) {
        pendingA9 = (
            sample.sampleID,
            VeilKernelDecisionSnapshot.fromA9(decision),
            VeilKernelComputeBudgetEnvelope.fromA9(budget),
            latencyNanos,
            cpuNanos
        )
    }

    func evaluateA10UltraShadow(sample: A10UltraOmegaSharedSample, runtime: VeilKernelRuntimeEnvironment? = nil) {
        guard let baseline = pendingA9, baseline.sampleID == sample.sampleID else {
            let nextDropped = state.droppedEventCount + 1
            state = A10UltraOmegaShadowState(
                cutoverStage: .stage0, testPhase: state.testPhase,
                validSharedSamples: state.validSharedSamples, exactMatches: state.exactMatches,
                d1Count: state.d1Count, d2Count: state.d2Count, d3Count: state.d3Count,
                d4Count: state.d4Count, d5Count: state.d5Count,
                droppedEventCount: nextDropped, fallbackEventCount: state.fallbackEventCount,
                productionCutover: "DENIED"
            )
            return
        }
        pendingA9 = nil
        let preliminary = A10UltraOmegaCompatibilityNormalizer.aggregate(sample.rawInput, persistenceSeconds: 0)
        let ultraPersistenceSeconds: Int
        if preliminary.light == 0 {
            ultraNonGreenSinceUptime = nil
            ultraPersistenceSeconds = 0
        } else if let since = ultraNonGreenSinceUptime, sample.uptime >= since {
            ultraPersistenceSeconds = min(9_999, Int(sample.uptime - since))
        } else {
            ultraNonGreenSinceUptime = sample.uptime
            ultraPersistenceSeconds = 0
        }

        let wallStart = A10UltraOmegaMetrics.monotonicNanos()
        let cpuStart = A10UltraOmegaMetrics.threadCPUNanos()
        let rssBefore = A10UltraOmegaMetrics.rssBytes()
        do {
            let result = try runner.evaluate(sample, persistenceSeconds: ultraPersistenceSeconds)
            let wallEnd = A10UltraOmegaMetrics.monotonicNanos()
            let cpuEnd = A10UltraOmegaMetrics.threadCPUNanos()
            let rss = max(rssBefore, A10UltraOmegaMetrics.rssBytes())
            let divergence = Self.classify(a9: baseline.decision, ultra: result.compatibilityDecision)
            let match = divergence == .d0
            let ultraCPU = cpuEnd &- cpuStart
            let combinedCPU = baseline.cpu &+ ultraCPU
            let energyProxy = max(1, combinedCPU) * UInt64(max(1, sample.rawInput.thermalLevel.rawValue + 1))
            let record = A10UltraOmegaComparisonRecord(
                sampleID: sample.sampleID, epoch: sample.epoch, timestamp: sample.timestamp,
                uptime: sample.uptime,
                sourceDomains: sample.sourceDomains, signalDigest: sample.signalDigest,
                a9: baseline.decision, ultra: result.compatibilityDecision,
                a9Budget: baseline.budget, ultraBudget: result.budget,
                decisionMatch: match, divergence: divergence,
                a9LatencyNanos: baseline.latency, ultraLatencyNanos: wallEnd &- wallStart,
                a9CPUNanos: baseline.cpu, ultraCPUNanos: ultraCPU,
                ultraPhysicalSlotCount: result.physicalSlotCount, rssBytes: rss,
                thermalState: sample.rawInput.thermalLevel.rawValue,
                batteryPermille: A10UltraOmegaMetrics.batteryPermille(), energyProxy: energyProxy,
                bleState: sample.rawInput.bluetoothRunning ? (sample.rawInput.connectedPeerCount > 0 ? "CONNECTED" : "RUNNING_NO_PEER") : "STOPPED",
                queueDepth: sample.rawInput.controlPendingPackets,
                droppedEventCount: state.droppedEventCount, ultraRestartCount: 0,
                fallbackEvent: false,
                guardianStatus: result.guardianStatus, rageStatus: result.rageStatus, vaultStatus: result.vaultStatus,
                runtimeBackend: result.backend,
                nativeIOSARM64Available: A10UltraOmegaRelease.nativeIOSARM64Available
            )
            lastComparison = record
            if let runtime { lastRuntimeSample = Self.runtimeRecord(from: record, environment: runtime) }
            state = Self.increment(state, divergence: divergence, fallback: false)
        } catch {
            let wallEnd = A10UltraOmegaMetrics.monotonicNanos()
            let cpuEnd = A10UltraOmegaMetrics.threadCPUNanos()
            let ultraCPU = cpuEnd &- cpuStart
            let combinedCPU = baseline.cpu &+ ultraCPU
            let record = A10UltraOmegaComparisonRecord(
                sampleID: sample.sampleID, epoch: sample.epoch, timestamp: sample.timestamp,
                uptime: sample.uptime,
                sourceDomains: sample.sourceDomains, signalDigest: sample.signalDigest,
                a9: baseline.decision, ultra: nil, a9Budget: baseline.budget, ultraBudget: nil,
                decisionMatch: false, divergence: .d5,
                a9LatencyNanos: baseline.latency, ultraLatencyNanos: wallEnd &- wallStart,
                a9CPUNanos: baseline.cpu, ultraCPUNanos: ultraCPU,
                ultraPhysicalSlotCount: 0, rssBytes: A10UltraOmegaMetrics.rssBytes(),
                thermalState: sample.rawInput.thermalLevel.rawValue,
                batteryPermille: A10UltraOmegaMetrics.batteryPermille(),
                energyProxy: max(1, combinedCPU) * UInt64(max(1, sample.rawInput.thermalLevel.rawValue + 1)),
                bleState: sample.rawInput.bluetoothRunning ? "RUNNING" : "STOPPED",
                queueDepth: sample.rawInput.controlPendingPackets,
                droppedEventCount: state.droppedEventCount, ultraRestartCount: 1,
                fallbackEvent: true,
                guardianStatus: "FAILED", rageStatus: "FAILED", vaultStatus: "FAILED",
                runtimeBackend: A10UltraOmegaRelease.runtimeBackend,
                nativeIOSARM64Available: A10UltraOmegaRelease.nativeIOSARM64Available
            )
            lastComparison = record
            if let runtime { lastRuntimeSample = Self.runtimeRecord(from: record, environment: runtime) }
            state = Self.increment(state, divergence: .d5, fallback: true)
        }
    }

    func recordA9Only(
        sample: A10UltraOmegaSharedSample,
        decision: VeilA9Decision,
        budget: VeilA9ComputePlan,
        latencyNanos: UInt64,
        cpuNanos: UInt64,
        runtime: VeilKernelRuntimeEnvironment
    ) {
        let a9 = VeilKernelDecisionSnapshot.fromA9(decision)
        let envelope = VeilKernelComputeBudgetEnvelope.fromA9(budget)
        let energyProxy = max(1, cpuNanos) * UInt64(max(1, sample.rawInput.thermalLevel.rawValue + 1))
        lastRuntimeSample = VeilKernelRuntimeSampleRecord(
            sampleID: sample.sampleID, epoch: sample.epoch, timestamp: sample.timestamp,
            sourceDomains: sample.sourceDomains, signalDigest: sample.signalDigest, environment: runtime,
            a9Decision: a9, ultraDecision: nil, a9Budget: envelope, ultraBudget: nil,
            decisionMatch: nil, divergenceClass: "NOT_COMPARABLE_A9_ONLY",
            a9LatencyNanos: latencyNanos, ultraLatencyNanos: 0,
            a9CPUNanos: cpuNanos, ultraCPUNanos: 0, ultraPhysicalSlotCount: 0,
            rssBytes: A10UltraOmegaMetrics.rssBytes(), thermalState: sample.rawInput.thermalLevel.rawValue,
            batteryPermille: A10UltraOmegaMetrics.batteryPermille(), energyProxy: energyProxy,
            bleState: Self.bleState(for: sample.rawInput), queueDepth: sample.rawInput.controlPendingPackets,
            droppedEventCount: state.droppedEventCount, ultraRestartCount: 0,
            fallbackEvent: false, guardianStatus: "NOT_ACTIVE", rageStatus: "NOT_ACTIVE", vaultStatus: "NOT_ACTIVE",
            runtimeBackend: "A9_ONLY"
        )
    }

    @discardableResult
    func evaluateA10UltraIsolated(
        sample: A10UltraOmegaSharedSample,
        runtime: VeilKernelRuntimeEnvironment
    ) -> A10UltraOmegaGovernanceResult? {
        let preliminary = A10UltraOmegaCompatibilityNormalizer.aggregate(sample.rawInput, persistenceSeconds: 0)
        let ultraPersistenceSeconds: Int
        if preliminary.light == 0 {
            ultraNonGreenSinceUptime = nil
            ultraPersistenceSeconds = 0
        } else if let since = ultraNonGreenSinceUptime, sample.uptime >= since {
            ultraPersistenceSeconds = min(9_999, Int(sample.uptime - since))
        } else {
            ultraNonGreenSinceUptime = sample.uptime
            ultraPersistenceSeconds = 0
        }

        let wallStart = A10UltraOmegaMetrics.monotonicNanos()
        let cpuStart = A10UltraOmegaMetrics.threadCPUNanos()
        let rssBefore = A10UltraOmegaMetrics.rssBytes()
        do {
            let result = try runner.evaluate(sample, persistenceSeconds: ultraPersistenceSeconds)
            let wallEnd = A10UltraOmegaMetrics.monotonicNanos()
            let cpuEnd = A10UltraOmegaMetrics.threadCPUNanos()
            let rss = max(rssBefore, A10UltraOmegaMetrics.rssBytes())
            let cpuNanos = cpuEnd &- cpuStart
            isolatedSampleCount &+= 1
            lastRuntimeSample = VeilKernelRuntimeSampleRecord(
                sampleID: sample.sampleID, epoch: sample.epoch, timestamp: sample.timestamp,
                sourceDomains: sample.sourceDomains, signalDigest: sample.signalDigest, environment: runtime,
                a9Decision: nil, ultraDecision: result.compatibilityDecision,
                a9Budget: nil, ultraBudget: result.budget,
                decisionMatch: nil,
                divergenceClass: runtime.mode == .a10Independent
                    ? "A10_INDEPENDENT_GOVERNANCE"
                    : "NOT_COMPARABLE_A10_ONLY_LAB",
                a9LatencyNanos: 0, ultraLatencyNanos: wallEnd &- wallStart,
                a9CPUNanos: 0, ultraCPUNanos: cpuNanos,
                ultraPhysicalSlotCount: result.physicalSlotCount, rssBytes: rss,
                thermalState: sample.rawInput.thermalLevel.rawValue,
                batteryPermille: A10UltraOmegaMetrics.batteryPermille(),
                energyProxy: max(1, cpuNanos) * UInt64(max(1, sample.rawInput.thermalLevel.rawValue + 1)),
                bleState: Self.bleState(for: sample.rawInput), queueDepth: sample.rawInput.controlPendingPackets,
                droppedEventCount: state.droppedEventCount, ultraRestartCount: 0,
                fallbackEvent: false, guardianStatus: result.guardianStatus, rageStatus: result.rageStatus, vaultStatus: result.vaultStatus,
                runtimeBackend: result.backend
            )
            return A10UltraOmegaGovernanceResult(
                decision: result.compatibilityDecision,
                budget: result.budget
            )
        } catch {
            let wallEnd = A10UltraOmegaMetrics.monotonicNanos()
            let cpuEnd = A10UltraOmegaMetrics.threadCPUNanos()
            lastRuntimeSample = VeilKernelRuntimeSampleRecord(
                sampleID: sample.sampleID, epoch: sample.epoch, timestamp: sample.timestamp,
                sourceDomains: sample.sourceDomains, signalDigest: sample.signalDigest, environment: runtime,
                a9Decision: nil, ultraDecision: nil, a9Budget: nil, ultraBudget: nil,
                decisionMatch: false, divergenceClass: A10UltraOmegaDivergenceClass.d5.rawValue,
                a9LatencyNanos: 0, ultraLatencyNanos: wallEnd &- wallStart,
                a9CPUNanos: 0, ultraCPUNanos: cpuEnd &- cpuStart,
                ultraPhysicalSlotCount: 0, rssBytes: A10UltraOmegaMetrics.rssBytes(),
                thermalState: sample.rawInput.thermalLevel.rawValue,
                batteryPermille: A10UltraOmegaMetrics.batteryPermille(), energyProxy: 0,
                bleState: Self.bleState(for: sample.rawInput), queueDepth: sample.rawInput.controlPendingPackets,
                droppedEventCount: state.droppedEventCount, ultraRestartCount: 1,
                fallbackEvent: true, guardianStatus: "FAILED", rageStatus: "FAILED", vaultStatus: "FAILED",
                runtimeBackend: A10UltraOmegaRelease.runtimeBackend
            )
            return nil
        }
    }

    func setTestPhase(_ phase: A10UltraOmegaTestPhase) {
        state = A10UltraOmegaShadowState(
            cutoverStage: .stage0, testPhase: phase,
            validSharedSamples: state.validSharedSamples, exactMatches: state.exactMatches,
            d1Count: state.d1Count, d2Count: state.d2Count, d3Count: state.d3Count,
            d4Count: state.d4Count, d5Count: state.d5Count,
            droppedEventCount: state.droppedEventCount, fallbackEventCount: state.fallbackEventCount,
            productionCutover: "DENIED"
        )
    }

    func report() -> String {
        [
            "VeilLink A10 Ultra Ω Shadow Accelerator",
            "Chip: \(A10UltraOmegaRelease.chipName)",
            "Architecture: \(A10UltraOmegaRelease.architecture) \(A10UltraOmegaRelease.architectureVersion)",
            "Release status: \(A10UltraOmegaRelease.releaseStatus)",
            "Runtime backend: \(A10UltraOmegaRelease.runtimeBackend)",
            "Native iOS arm64: \(A10UltraOmegaRelease.nativeIOSARM64Available ? "available" : "not available")",
            "Cutover stage: \(state.cutoverStage.rawValue)",
            "Test phase: \(state.testPhase.rawValue)",
            "Valid shared samples: \(state.validSharedSamples)",
            "D0/D1/D2/D3/D4/D5: \(state.exactMatches)/\(state.d1Count)/\(state.d2Count)/\(state.d3Count)/\(state.d4Count)/\(state.d5Count)",
            "Dropped events: \(state.droppedEventCount)",
            "Fallback events: \(state.fallbackEventCount)",
            "Isolated lab samples: \(isolatedSampleCount)",
            "Runtime epoch resets: \(runtimeEpochResetCount) · last \(lastRuntimeEpochResetReason)",
            "Mutation authority: 0",
            "PRODUCTION_CUTOVER: DENIED",
            "Native limitation: \(A10UltraOmegaRelease.nativeBackendLimitation)"
        ].joined(separator: "\n")
    }

    static func timingStart() -> (wall: UInt64, cpu: UInt64) {
        (A10UltraOmegaMetrics.monotonicNanos(), A10UltraOmegaMetrics.threadCPUNanos())
    }

    static func timingElapsed(from start: (wall: UInt64, cpu: UInt64)) -> (wall: UInt64, cpu: UInt64) {
        let wall = A10UltraOmegaMetrics.monotonicNanos()
        let cpu = A10UltraOmegaMetrics.threadCPUNanos()
        return (wall &- start.wall, cpu &- start.cpu)
    }

    private static func runtimeRecord(
        from record: A10UltraOmegaComparisonRecord,
        environment: VeilKernelRuntimeEnvironment
    ) -> VeilKernelRuntimeSampleRecord {
        VeilKernelRuntimeSampleRecord(
            sampleID: record.sampleID, epoch: record.epoch, timestamp: record.timestamp,
            sourceDomains: record.sourceDomains, signalDigest: record.signalDigest, environment: environment,
            a9Decision: record.a9, ultraDecision: record.ultra,
            a9Budget: record.a9Budget, ultraBudget: record.ultraBudget,
            decisionMatch: record.decisionMatch, divergenceClass: record.divergence.rawValue,
            a9LatencyNanos: record.a9LatencyNanos, ultraLatencyNanos: record.ultraLatencyNanos,
            a9CPUNanos: record.a9CPUNanos, ultraCPUNanos: record.ultraCPUNanos,
            ultraPhysicalSlotCount: record.ultraPhysicalSlotCount, rssBytes: record.rssBytes,
            thermalState: record.thermalState, batteryPermille: record.batteryPermille,
            energyProxy: record.energyProxy, bleState: record.bleState, queueDepth: record.queueDepth,
            droppedEventCount: record.droppedEventCount, ultraRestartCount: record.ultraRestartCount,
            fallbackEvent: record.fallbackEvent,
            guardianStatus: record.guardianStatus, rageStatus: record.rageStatus, vaultStatus: record.vaultStatus,
            runtimeBackend: record.runtimeBackend
        )
    }

    private static func bleState(for input: VeilA9Input) -> String {
        input.bluetoothRunning ? (input.connectedPeerCount > 0 ? "CONNECTED" : "RUNNING_NO_PEER") : "STOPPED"
    }

    private static func classify(a9: VeilKernelDecisionSnapshot, ultra: VeilKernelDecisionSnapshot) -> A10UltraOmegaDivergenceClass {
        if a9.compatibilityFingerprint == ultra.compatibilityFingerprint { return .d0 }
        let a9Red = a9.light == "红色"
        let ultraRed = ultra.light == "红色"
        if (a9Red && !ultraRed) || (a9.level >= 3 && ultra.level < a9.level) || (a9.preflight == .stopRecommended && ultra.preflight != .stopRecommended) {
            return .d4
        }
        if a9.light != ultra.light || a9.level != ultra.level || a9.preflight != ultra.preflight {
            return .d3
        }
        return .d2
    }

    private static func increment(_ old: A10UltraOmegaShadowState, divergence: A10UltraOmegaDivergenceClass, fallback: Bool) -> A10UltraOmegaShadowState {
        A10UltraOmegaShadowState(
            cutoverStage: .stage0,
            testPhase: old.testPhase,
            validSharedSamples: old.validSharedSamples + 1,
            exactMatches: old.exactMatches + (divergence == .d0 ? 1 : 0),
            d1Count: old.d1Count + (divergence == .d1 ? 1 : 0),
            d2Count: old.d2Count + (divergence == .d2 ? 1 : 0),
            d3Count: old.d3Count + (divergence == .d3 ? 1 : 0),
            d4Count: old.d4Count + (divergence == .d4 ? 1 : 0),
            d5Count: old.d5Count + (divergence == .d5 ? 1 : 0),
            droppedEventCount: old.droppedEventCount,
            fallbackEventCount: old.fallbackEventCount + (fallback ? 1 : 0),
            productionCutover: "DENIED"
        )
    }

    private static func signalDigest(input: VeilA9Input, context: A10UltraOmegaHostContext, epoch: UInt64, timestamp: Date) -> String {
        let fields: [String] = [
            String(epoch), String(format: "%.6f", timestamp.timeIntervalSince1970), input.transportCoverage.rawValue,
            String(input.bluetoothRunning), String(input.connectedPeerCount), String(input.trackedPeerCount),
            String(input.recoveringPeerCount), String(input.weakPeerCount), String(input.marginalPeerCount),
            String(input.minimumLinkHealth ?? -1), String(input.maximumReconnectAttempt), String(input.pendingBytes),
            String(input.controlPendingPackets), String(input.maximumStallMilliseconds), String(input.agentUnavailable),
            String(input.agentCooling), String(input.agentHasFailure), String(input.thermalLevel.rawValue),
            String(input.lowPowerMode), input.databaseIntegrity.title, String(context.foregroundActive),
            String(context.systemAvailable), context.gameRuntimeState, String(context.activeProcessorCount),
            String(context.physicalMemoryBytes)
        ]
        let digestInput = fields.joined(separator: "|")
        let digest = SHA256.hash(data: Data(digestInput.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
