import Combine
import Foundation

enum MaleCNSGraphManagerState: Equatable {
    case unloaded
    case loading
    case missing
    case ready(MaleCNSGraphRuntimeProfile)
    case failed(String)

    var displayName: String {
        switch self {
        case .unloaded: return "未载入"
        case .loading: return "载入中"
        case .missing: return "未安装 VFLY"
        case .ready(let profile): return "\(profile.tier.rawValue) · \(profile.neuronCount)N"
        case .failed: return "载入失败"
        }
    }
}

/// Lazy bridge from packaged VFLY assets to the A9-governed native runtime. The app never parses
/// Feather/NPZ files. Legacy devices accept Lite only; balanced/high devices accept Core or Lite.
/// Reference/full graphs are a build-host research artifact and are rejected on every phone tier.
@MainActor
final class MaleCNSGraphManager: ObservableObject {
    @Published private(set) var state: MaleCNSGraphManagerState = .unloaded
    @Published private(set) var lastProbe: MaleCNSNativeEpisodeReadoutResult?

    private let profile: AgentCapabilityProfile
    private weak var governor: VeilA9ComputeGovernor?
    private var runtime: MaleCNSGraphRuntime?
    private var loadTask: Task<Void, Never>?

    init(profile: AgentCapabilityProfile, governor: VeilA9ComputeGovernor) {
        self.profile = profile
        self.governor = governor
    }

    nonisolated static func allowedGraphTiers(for computeTier: AgentComputeTier) -> Set<MaleCNSGraphTier> {
        switch computeTier {
        case .legacyA10: return [.lite]
        case .balanced, .high: return [.core, .lite]
        }
    }

    func prepareFromBundle(_ bundle: Bundle = .main) {
        guard loadTask == nil else { return }
        switch state {
        case .ready, .loading: return
        default: break
        }

        let candidateNames: [String]
        switch profile.tier {
        case .legacyA10: candidateNames = ["VeilFlyLite"]
        case .balanced, .high: candidateNames = ["VeilFlyCore", "VeilFlyLite"]
        }
        let urls = candidateNames.compactMap { bundle.url(forResource: $0, withExtension: "vfly") }
        guard !urls.isEmpty else {
            state = .missing
            return
        }

        let allowedTiers = Self.allowedGraphTiers(for: profile.tier)
        state = .loading
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.loadTask = nil }
            do {
                let runtime = try await Task.detached(priority: .utility) {
                    try Self.loadFirstCompatibleRuntime(urls: urls, allowedTiers: allowedTiers)
                }.value
                self.runtime = runtime
                self.governor?.bindMaleCNSConsumer(runtime)
                self.state = .ready(runtime.profile)
            } catch {
                self.governor?.bindMaleCNSConsumer(nil)
                self.runtime = nil
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    /// Runs a bounded validation stimulus off the MainActor. The runtime serializes its native
    /// state internally; if the graph is unloaded while the probe is running, its result is not
    /// published back into UI state.
    @discardableResult
    func runProbe(_ stimulus: MaleCNSStimulus, requestedSteps: Int? = nil) async throws -> MaleCNSNativeEpisodeReadoutResult {
        guard let runtime else { throw VFLY1Error.invalidMetadata }
        let result = try await Task.detached(priority: .userInitiated) {
            try runtime.run(stimulus: stimulus, requestedSteps: requestedSteps)
        }.value
        guard self.runtime === runtime else { throw CancellationError() }
        lastProbe = result
        return result
    }

    func trim() {
        runtime?.trimComputeState()
        lastProbe = nil
    }

    func unload() {
        loadTask?.cancel(); loadTask = nil
        governor?.bindMaleCNSConsumer(nil)
        runtime?.trimComputeState()
        runtime = nil
        lastProbe = nil
        state = .unloaded
    }

    private nonisolated static func loadFirstCompatibleRuntime(
        urls: [URL],
        allowedTiers: Set<MaleCNSGraphTier>
    ) throws -> MaleCNSGraphRuntime {
        var lastError: Error = VFLY1Error.incompatibleTier
        for url in urls {
            do {
                let artifact = try VFLY1Loader.load(url: url)
                let candidate = try MaleCNSGraphRuntime(artifact: artifact)
                guard allowedTiers.contains(candidate.profile.tier) else {
                    lastError = VFLY1Error.incompatibleTier
                    continue
                }
                return candidate
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
