import Foundation
import UIKit

struct A10UltraM5GovernanceSnapshot: Equatable, Sendable {
    let evaluatedAt: Date
    let states: [String]
    let stateProbabilities: [String: Double]
    let actionProposals: [String]
    let outputDigest: String
    let latencyNanoseconds: UInt64
    let backend: String
    let modelHash: String
    let featureAdapter: String
    let mutationAuthority: Int
    let recommendation: String

    static let idle = A10UltraM5GovernanceSnapshot(
        evaluatedAt: .distantPast,
        states: [],
        stateProbabilities: [:],
        actionProposals: [],
        outputDigest: "-",
        latencyNanoseconds: 0,
        backend: "not-loaded",
        modelHash: "c5ba826dab1ebe1db02e90e8b4bfd2c060e99586413970fa3bd4d848e378a8b4",
        featureAdapter: A10UltraM5FeatureAdapter.version,
        mutationAuthority: 0,
        recommendation: "SHADOW_ADVISORY_ONLY"
    )
}

@MainActor
final class A10UltraM5GovernanceAdvisor: ObservableObject {
    @Published private(set) var snapshot: A10UltraM5GovernanceSnapshot = .idle
    @Published private(set) var lastError: String?

    private let runtime: A10UltraM5Runtime
    private var evaluationTask: Task<Void, Never>?
    private var evaluationSequence: UInt64 = 0

    init(runtime: A10UltraM5Runtime) {
        self.runtime = runtime
    }

    func evaluate(
        input: VeilA9Input,
        foregroundActive: Bool,
        agentGenerating: Bool,
        gameActive: Bool
    ) {
        evaluationTask?.cancel()
        evaluationSequence &+= 1
        let sequence = evaluationSequence
        let battery = UIDevice.current.batteryLevel
        let features = A10UltraM5FeatureAdapter.features(
            input: input,
            foregroundActive: foregroundActive,
            batteryLevel: battery,
            agentGenerating: agentGenerating,
            gameActive: gameActive
        )
        let text = Self.hostStatePrompt(input: input)
        let numeric = Dictionary(uniqueKeysWithValues: features.enumerated().map { ("f\($0.offset)", Double($0.element)) })
        let request = A10UltraComputeRequest(
            task: .structuredReasoning,
            textInputs: [text],
            numericInputs: numeric,
            metadata: [
                "domain": "veillink",
                "source": "VEILLINK_HOST_STATE",
                "feature_adapter": A10UltraM5FeatureAdapter.version,
                "mutation_authority": "0"
            ]
        )

        evaluationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await self.runtime.execute(request)
                guard !Task.isCancelled, sequence == self.evaluationSequence else { return }
                let states = response.runtimeMetadata["states"]?
                    .split(separator: ",")
                    .map(String.init)
                    .filter { !$0.isEmpty } ?? []
                let generatedTokens = response.runtimeMetadata["generated_tokens"]?
                    .split(separator: ",")
                    .map(String.init) ?? []
                var probabilities: [String: Double] = [:]
                let names = [
                    "S_LINK_BAD", "S_RECONNECT", "S_QUEUE", "S_THERMAL", "S_DB_STALL", "S_RESOURCE",
                    "S_NORMAL", "S_SUSPICIOUS", "S_CORRUPTED", "S_HIGH_RISK", "S_UNKNOWN"
                ]
                for (index, name) in names.enumerated() {
                    if let value = response.numericOutputs["state_probability_\(index)"] {
                        probabilities[name] = value
                    }
                }
                self.snapshot = A10UltraM5GovernanceSnapshot(
                    evaluatedAt: Date(),
                    states: states,
                    stateProbabilities: probabilities,
                    actionProposals: Self.actionProposals(from: generatedTokens),
                    outputDigest: response.runtimeMetadata["output_digest"] ?? "-",
                    latencyNanoseconds: UInt64(response.runtimeMetadata["latency_ns"] ?? "0") ?? 0,
                    backend: response.runtimeMetadata["backend"] ?? "unknown",
                    modelHash: response.runtimeMetadata["model_hash"] ?? self.runtime.manifest.artifactDigest,
                    featureAdapter: A10UltraM5FeatureAdapter.version,
                    mutationAuthority: 0,
                    recommendation: "SHADOW_ADVISORY_ONLY"
                )
                self.lastError = nil
            } catch is CancellationError {
                return
            } catch A10UltraComputeError.cancelled {
                return
            } catch {
                guard sequence == self.evaluationSequence else { return }
                self.lastError = error.localizedDescription
            }
        }
    }

    func cancel() {
        evaluationTask?.cancel()
        evaluationTask = nil
    }

    func report() -> String {
        let states = snapshot.states.isEmpty ? "none" : snapshot.states.joined(separator: ",")
        let actions = snapshot.actionProposals.isEmpty ? "none" : snapshot.actionProposals.joined(separator: ",")
        return [
            "A10 Ultra Ω M5 Governance Advisor",
            "Mode: TRAINED_COGNITION_SHADOW",
            "States: \(states)",
            "Action proposals: \(actions)",
            "Feature adapter: \(snapshot.featureAdapter)",
            "Backend: \(snapshot.backend)",
            "Model: \(snapshot.modelHash)",
            "Latency: \(snapshot.latencyNanoseconds) ns",
            "Mutation authority: 0",
            "Recommendation: SHADOW_ADVISORY_ONLY",
            "Last error: \(lastError ?? "none")"
        ].joined(separator: "\n")
    }

    private static func hostStatePrompt(input: VeilA9Input) -> String {
        var parts = ["VeilLink 蓝牙链路状态，总结并给出建议。"]
        if input.weakPeerCount > 0 || (input.minimumLinkHealth ?? 100) < 45 { parts.append("链路弱，可能丢包。") }
        if input.recoveringPeerCount > 0 || input.maximumReconnectAttempt > 0 { parts.append("存在重连。") }
        if input.pendingBytes > 64 * 1_024 || input.controlPendingPackets > 8 { parts.append("队列拥塞。") }
        if input.thermalLevel.rawValue >= VeilA9ThermalLevel.serious.rawValue { parts.append("温度热，资源压力。") }
        if input.databaseIntegrity == .failed { parts.append("数据库损坏风险。") }
        if input.agentCooling || input.agentHasFailure || input.lowPowerMode { parts.append("CPU 内存资源不足。") }
        if parts.count == 1 { parts.append("当前状态正常。") }
        return parts.joined(separator: " ")
    }

    private static func actionProposals(from tokens: [String]) -> [String] {
        var proposals: [String] = []
        func add(_ value: String) { if !proposals.contains(value) { proposals.append(value) } }
        for token in tokens {
            switch token {
            case "A_REDUCE_RATE": add("REVIEW_SEND_RATE_THROTTLE")
            case "A_RECONNECT_REVIEW": add("REVIEW_SECURE_RECONNECT")
            case "A_DRAIN_QUEUE": add("REVIEW_QUEUE_DRAIN")
            case "A_COOL_DOWN": add("REVIEW_COMPUTE_COOLDOWN")
            case "A_DB_REVIEW": add("RUN_READONLY_DB_REVIEW")
            case "A_CONSERVE": add("REVIEW_RESOURCE_CONSERVATION")
            case "A_SCHEMA_REVIEW": add("REVIEW_STORAGE_SCHEMA")
            case "A_QUARANTINE_COPY": add("REVIEW_DATABASE_COPY_QUARANTINE")
            case "A_BACKUP_FIRST": add("REVIEW_BACKUP_FIRST")
            case "A_NEED_MORE": add("COLLECT_MORE_TELEMETRY")
            case "A_NO_ACTION", "A_OBSERVE": add("OBSERVE_ONLY")
            case "A_READ_ONLY": add("KEEP_READ_ONLY")
            default: break
            }
        }
        return proposals
    }
}
