import Combine
import Foundation

/// Versioned host-side ABI between VeilLink and the lattice-kernel family.
///
/// I6 intentionally keeps A9 as the active compatibility baseline. A10 may only attach through
/// this bridge, first in shadow validation, so the host can prove that the A9 compatibility
/// profile produces zero unexpected decision drift before any future cutover.
enum VeilKernelSignalBus {
    static let version = 1
}

enum VeilKernelIntegrationStage: String, Codable, Sendable {
    case a10IntegrationReady = "A10_INTEGRATION_READY"
    case a10ShadowValidation = "A10_SHADOW_VALIDATION"
    case a10Active = "A10_ACTIVE"

    var title: String {
        switch self {
        case .a10IntegrationReady: return "A10 对接准备 / 个性化适配"
        case .a10ShadowValidation: return "A10 影子兼容验证"
        case .a10Active: return "A10 已切换"
        }
    }
}

enum VeilKernelAuthority: String, Codable, Sendable {
    case advisoryOnly = "ADVISORY_ONLY"
}

enum VeilKernelFaultDomain: String, Codable, CaseIterable, Sendable {
    case storage
    case transport
    case system
    case agent
    case game
    case lifecycle
}

struct VeilKernelHostProfile: Equatable, Sendable {
    let hostID: String
    let compatibilityProfileID: String
    let candidateProfileTargetID: String
    let signalBusVersion: Int
    let authority: VeilKernelAuthority
    let faultDomains: Set<VeilKernelFaultDomain>
    let canMutateTransport: Bool
    let canMutateStorage: Bool
    let canMutateGameState: Bool
    let canReadSecrets: Bool
    let allowsCloudScheduling: Bool
    let allowsPeerComputeOffload: Bool

    static let veilLink = VeilKernelHostProfile(
        hostID: "VeilLink",
        compatibilityProfileID: "veillink.a9.compat.v1",
        candidateProfileTargetID: "veillink.a10.profile.v1",
        signalBusVersion: VeilKernelSignalBus.version,
        authority: .advisoryOnly,
        faultDomains: Set(VeilKernelFaultDomain.allCases),
        canMutateTransport: false,
        canMutateStorage: false,
        canMutateGameState: false,
        canReadSecrets: false,
        allowsCloudScheduling: false,
        allowsPeerComputeOffload: false
    )
}

struct VeilKernelSignalFrame: Equatable, Sendable {
    let schemaVersion: Int
    let hostID: String
    let profileID: String
    let generatedAt: Date
    let integerSignals: [String: Int]
    let booleanSignals: [String: Bool]
    let textSignals: [String: String]

    static func fromA9(_ input: VeilA9Input, generatedAt: Date = Date()) -> VeilKernelSignalFrame {
        VeilKernelSignalFrame(
            schemaVersion: VeilKernelSignalBus.version,
            hostID: VeilKernelHostProfile.veilLink.hostID,
            profileID: VeilKernelHostProfile.veilLink.compatibilityProfileID,
            generatedAt: generatedAt,
            integerSignals: [
                "transport.connected_peer_count": input.connectedPeerCount,
                "transport.tracked_peer_count": input.trackedPeerCount,
                "transport.recovering_peer_count": input.recoveringPeerCount,
                "transport.weak_peer_count": input.weakPeerCount,
                "transport.marginal_peer_count": input.marginalPeerCount,
                "transport.minimum_link_health": input.minimumLinkHealth ?? -1,
                "transport.maximum_reconnect_attempt": input.maximumReconnectAttempt,
                "transport.pending_bytes": input.pendingBytes,
                "transport.control_pending_packets": input.controlPendingPackets,
                "transport.maximum_stall_ms": input.maximumStallMilliseconds,
                "system.thermal_level": input.thermalLevel.rawValue
            ],
            booleanSignals: [
                "transport.bluetooth_running": input.bluetoothRunning,
                "agent.unavailable": input.agentUnavailable,
                "agent.cooling": input.agentCooling,
                "agent.has_failure": input.agentHasFailure,
                "system.low_power_mode": input.lowPowerMode,
                "storage.integrity_failed": input.databaseIntegrity == .failed
            ],
            textSignals: [
                "transport.coverage": input.transportCoverage.rawValue,
                "storage.database_integrity": input.databaseIntegrity.title
            ]
        )
    }
}

struct VeilKernelIssueSnapshot: Equatable, Sendable {
    let severity: String
    let source: String
    let code: String
}

enum VeilKernelPreflightRecommendation: String, Codable, Sendable {
    case proceed = "PROCEED"
    case review = "REVIEW"
    case stopRecommended = "STOP_RECOMMENDED"
}

struct VeilKernelDecisionSnapshot: Equatable, Sendable {
    let profileID: String
    let light: String
    let level: Int
    let reasonCode: String
    let healthScore: Int
    let riskBasisPoints: Int
    let persistenceSeconds: Int
    let latticeCell: Int
    let issues: [VeilKernelIssueSnapshot]
    let preflight: VeilKernelPreflightRecommendation

    static func fromA9(_ decision: VeilA9Decision) -> VeilKernelDecisionSnapshot {
        let preflight: VeilKernelPreflightRecommendation
        if decision.issues.contains(where: { $0.severity == .p0 }) {
            preflight = .stopRecommended
        } else if decision.light == .green {
            preflight = .proceed
        } else {
            preflight = .review
        }
        return VeilKernelDecisionSnapshot(
            profileID: VeilKernelHostProfile.veilLink.compatibilityProfileID,
            light: decision.light.title,
            level: decision.level.rawValue,
            reasonCode: decision.reasonCode,
            healthScore: decision.healthScore,
            riskBasisPoints: Int((decision.riskPoints * 100).rounded()),
            persistenceSeconds: decision.persistenceSeconds,
            latticeCell: decision.latticeIndex,
            issues: decision.issues
                .map { VeilKernelIssueSnapshot(severity: $0.severity.rawValue, source: $0.source, code: $0.code) }
                .sorted { lhs, rhs in
                    if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }
                    if lhs.source != rhs.source { return lhs.source < rhs.source }
                    return lhs.code < rhs.code
                },
            preflight: preflight
        )
    }

    var compatibilityFingerprint: String {
        let issueText = issues.map { "\($0.severity):\($0.source):\($0.code)" }.joined(separator: "|")
        let canonical = [
            profileID, light, String(level), reasonCode, String(healthScore), String(riskBasisPoints),
            String(persistenceSeconds), String(latticeCell), preflight.rawValue, issueText
        ].joined(separator: "#")
        return VeilKernelFingerprint.fnv1a64(canonical)
    }
}

struct VeilKernelComputeBudgetEnvelope: Equatable, Sendable {
    let mode: String
    let focus: String
    let latticeCell: Int
    let totalUnits: Int
    let transportReserveUnits: Int
    let maleCNSUnits: Int
    let languageUnits: Int
    let visionUnits: Int
    let gameUnits: Int
    let trainingUnits: Int

    static func fromA9(_ plan: VeilA9ComputePlan) -> VeilKernelComputeBudgetEnvelope {
        VeilKernelComputeBudgetEnvelope(
            mode: plan.mode.rawValue,
            focus: plan.focus.rawValue,
            latticeCell: plan.latticeIndex,
            totalUnits: plan.totalComputeUnits,
            transportReserveUnits: plan.transportReserveUnits,
            maleCNSUnits: plan.maleCNSUnits,
            languageUnits: plan.languageUnits,
            visionUnits: plan.visionUnits,
            gameUnits: plan.gameUnits,
            trainingUnits: plan.trainingUnits
        )
    }
}

/// Future A10 implementations conform here. The runtime receives only sanitized host signals and
/// returns advisory decisions; it never receives database handles, transport objects, game state
/// mutators, private/session keys or direct tool-execution authority.
protocol VeilLatticeKernelRuntimeAdapter {
    var profileID: String { get }
    var signalBusVersion: Int { get }
    func evaluate(_ frame: VeilKernelSignalFrame) throws -> VeilKernelDecisionSnapshot
}

struct VeilKernelRuntimeSnapshot: Equatable, Sendable {
    let stage: VeilKernelIntegrationStage
    let activeProfileID: String
    let candidateProfileID: String?
    let authority: VeilKernelAuthority
    let signalBusVersion: Int
    let baselineFingerprint: String?
    let candidateFingerprint: String?
    let unexpectedDecisionDiffs: Int
    let computeMode: String?

    static let initial = VeilKernelRuntimeSnapshot(
        stage: .a10IntegrationReady,
        activeProfileID: VeilKernelHostProfile.veilLink.compatibilityProfileID,
        candidateProfileID: nil,
        authority: .advisoryOnly,
        signalBusVersion: VeilKernelSignalBus.version,
        baselineFingerprint: nil,
        candidateFingerprint: nil,
        unexpectedDecisionDiffs: 0,
        computeMode: nil
    )
}

@MainActor
final class VeilLatticeKernelBridge: ObservableObject {
    @Published private(set) var snapshot: VeilKernelRuntimeSnapshot = .initial
    @Published private(set) var lastSignalFrame: VeilKernelSignalFrame?
    @Published private(set) var baselineDecision: VeilKernelDecisionSnapshot?
    @Published private(set) var candidateDecision: VeilKernelDecisionSnapshot?
    @Published private(set) var computeBudget: VeilKernelComputeBudgetEnvelope?

    let hostProfile = VeilKernelHostProfile.veilLink

    func recordA9Compatibility(input: VeilA9Input, decision: VeilA9Decision, generatedAt: Date = Date()) {
        lastSignalFrame = .fromA9(input, generatedAt: generatedAt)
        let baseline = VeilKernelDecisionSnapshot.fromA9(decision)
        baselineDecision = baseline
        snapshot = VeilKernelRuntimeSnapshot(
            stage: snapshot.stage == .a10Active ? .a10Active : snapshot.stage,
            activeProfileID: snapshot.stage == .a10Active ? snapshot.activeProfileID : hostProfile.compatibilityProfileID,
            candidateProfileID: snapshot.candidateProfileID,
            authority: .advisoryOnly,
            signalBusVersion: hostProfile.signalBusVersion,
            baselineFingerprint: baseline.compatibilityFingerprint,
            candidateFingerprint: snapshot.candidateFingerprint,
            unexpectedDecisionDiffs: snapshot.unexpectedDecisionDiffs,
            computeMode: snapshot.computeMode
        )
    }

    func recordComputePlan(_ plan: VeilA9ComputePlan) {
        let budget = VeilKernelComputeBudgetEnvelope.fromA9(plan)
        computeBudget = budget
        snapshot = VeilKernelRuntimeSnapshot(
            stage: snapshot.stage,
            activeProfileID: snapshot.activeProfileID,
            candidateProfileID: snapshot.candidateProfileID,
            authority: snapshot.authority,
            signalBusVersion: snapshot.signalBusVersion,
            baselineFingerprint: snapshot.baselineFingerprint,
            candidateFingerprint: snapshot.candidateFingerprint,
            unexpectedDecisionDiffs: snapshot.unexpectedDecisionDiffs,
            computeMode: budget.mode
        )
    }

    /// Starts compatibility shadowing only. I6 deliberately provides no public cutover method.
    func beginA10ShadowValidation(candidateProfileID: String) {
        candidateDecision = nil
        snapshot = VeilKernelRuntimeSnapshot(
            stage: .a10ShadowValidation,
            activeProfileID: hostProfile.compatibilityProfileID,
            candidateProfileID: candidateProfileID,
            authority: .advisoryOnly,
            signalBusVersion: hostProfile.signalBusVersion,
            baselineFingerprint: snapshot.baselineFingerprint,
            candidateFingerprint: nil,
            unexpectedDecisionDiffs: 0,
            computeMode: snapshot.computeMode
        )
    }

    /// Records one A10 compatibility-profile shadow result. The A9 result remains authoritative.
    func recordA10ShadowDecision(_ decision: VeilKernelDecisionSnapshot) {
        guard snapshot.stage == .a10ShadowValidation else { return }
        candidateDecision = decision
        let candidateFingerprint = decision.compatibilityFingerprint
        let differs = snapshot.baselineFingerprint.map { $0 != candidateFingerprint } ?? false
        snapshot = VeilKernelRuntimeSnapshot(
            stage: .a10ShadowValidation,
            activeProfileID: hostProfile.compatibilityProfileID,
            candidateProfileID: snapshot.candidateProfileID ?? decision.profileID,
            authority: .advisoryOnly,
            signalBusVersion: hostProfile.signalBusVersion,
            baselineFingerprint: snapshot.baselineFingerprint,
            candidateFingerprint: candidateFingerprint,
            unexpectedDecisionDiffs: snapshot.unexpectedDecisionDiffs + (differs ? 1 : 0),
            computeMode: snapshot.computeMode
        )
    }

    func resetToIntegrationReady() {
        candidateDecision = nil
        snapshot = VeilKernelRuntimeSnapshot(
            stage: .a10IntegrationReady,
            activeProfileID: hostProfile.compatibilityProfileID,
            candidateProfileID: nil,
            authority: .advisoryOnly,
            signalBusVersion: hostProfile.signalBusVersion,
            baselineFingerprint: baselineDecision?.compatibilityFingerprint,
            candidateFingerprint: nil,
            unexpectedDecisionDiffs: 0,
            computeMode: computeBudget?.mode
        )
    }

    func report() -> String {
        [
            "VeilLink Universal Lattice Kernel Bridge",
            "Stage: \(snapshot.stage.rawValue) · \(snapshot.stage.title)",
            "Active profile: \(snapshot.activeProfileID)",
            "A10 target profile: \(hostProfile.candidateProfileTargetID)",
            "Candidate profile: \(snapshot.candidateProfileID ?? "none")",
            "Signal Bus: v\(snapshot.signalBusVersion)",
            "Authority: \(snapshot.authority.rawValue)",
            "Baseline fingerprint: \(snapshot.baselineFingerprint ?? "not-evaluated")",
            "Candidate fingerprint: \(snapshot.candidateFingerprint ?? "none")",
            "Unexpected decision diffs: \(snapshot.unexpectedDecisionDiffs)",
            "Compute mode: \(snapshot.computeMode ?? "not-reported")",
            "Fault domains: \(hostProfile.faultDomains.map(\.rawValue).sorted().joined(separator: ", "))",
            "Mutation authority: transport=no · storage=no · game=no · secrets=no",
            "Cloud scheduling: no · peer compute offload: no",
            "Cutover gate: external release process only after A9-compat shadow diff=0 + build/test acceptance."
        ].joined(separator: "\n")
    }
}

private enum VeilKernelFingerprint {
    static func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
