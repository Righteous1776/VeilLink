import Foundation

/// New compute-facing ABI for the future A10 Ultra Ω runtime.
///
/// This is intentionally separate from the historical OMEGA 96 governance-shadow lane.
/// The compute core never receives BLE/SQLite/tool objects or secret-bearing handles. It only
/// receives host-sanitized requests plus an A9-derived resource budget.
enum A10UltraComputeTaskKind: String, Codable, CaseIterable, Hashable, Sendable {
    case textGeneration = "TEXT_GENERATION"
    case structuredReasoning = "STRUCTURED_REASONING"
    case candidateRanking = "CANDIDATE_RANKING"
    case gamePlanning = "GAME_PLANNING"
    case visionAnalysis = "VISION_ANALYSIS"
    case embedding = "EMBEDDING"
}

enum A10UltraComputeState: String, Codable, CaseIterable, Sendable {
    case detached = "DETACHED"
    case unloaded = "UNLOADED"
    case loading = "LOADING"
    case ready = "READY"
    case computing = "COMPUTING"
    case cooling = "COOLING"
    case failed = "FAILED"
}

struct A10UltraComputeManifest: Equatable, Sendable {
    let runtimeID: String
    let displayName: String
    let abiVersion: Int
    let artifactDigest: String
    let supportedTasks: Set<A10UltraComputeTaskKind>
    let supportsStreaming: Bool
    let supportsCancellation: Bool
    let supportsStateSnapshot: Bool
    let minimumOSMajor: Int
    let notes: String
}

struct A10UltraComputeBudget: Equatable, Sendable {
    let mode: String
    let focus: String
    let totalUnits: Int
    let transportReserveUnits: Int
    let languageUnits: Int
    let visionUnits: Int
    let gameUnits: Int
    let maleCNSUnits: Int
    let trainingUnits: Int

    static func fromA9(_ plan: VeilA9ComputePlan) -> A10UltraComputeBudget {
        A10UltraComputeBudget(
            mode: plan.mode.rawValue,
            focus: plan.focus.rawValue,
            totalUnits: plan.totalComputeUnits,
            transportReserveUnits: plan.transportReserveUnits,
            languageUnits: plan.languageUnits,
            visionUnits: plan.visionUnits,
            gameUnits: plan.gameUnits,
            maleCNSUnits: plan.maleCNSUnits,
            trainingUnits: plan.trainingUnits
        )
    }
}

struct A10UltraComputeBlob: Equatable, Sendable {
    let mimeType: String
    let data: Data

    init(mimeType: String, data: Data) {
        self.mimeType = mimeType
        self.data = data
    }
}

struct A10UltraComputeRequest: Equatable, Sendable {
    let jobID: String
    let task: A10UltraComputeTaskKind
    let textInputs: [String]
    let numericInputs: [String: Double]
    let blobs: [A10UltraComputeBlob]
    let metadata: [String: String]

    init(
        jobID: String = UUID().uuidString,
        task: A10UltraComputeTaskKind,
        textInputs: [String] = [],
        numericInputs: [String: Double] = [:],
        blobs: [A10UltraComputeBlob] = [],
        metadata: [String: String] = [:]
    ) {
        self.jobID = jobID
        self.task = task
        self.textInputs = textInputs
        self.numericInputs = numericInputs
        self.blobs = blobs
        self.metadata = metadata
    }
}

struct A10UltraComputeResponse: Equatable, Sendable {
    let jobID: String
    let textOutputs: [String]
    let numericOutputs: [String: Double]
    let opaquePayload: Data?
    let runtimeMetadata: [String: String]
}

enum A10UltraComputeError: LocalizedError, Equatable {
    case unavailable(String)
    case unsupported(A10UltraComputeTaskKind)
    case cancelled
    case invalidRequest(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        case .unsupported(let task): return "A10 Ultra Ω 当前运行时不支持任务：\(task.rawValue)。"
        case .cancelled: return "A10 Ultra Ω 计算已停止。"
        case .invalidRequest(let reason): return "A10 Ultra Ω 请求无效：\(reason)"
        }
    }
}

/// Future native / Swift / Metal / ANE implementations attach here.
///
/// Mutation authority is deliberately absent from this protocol. A conforming runtime cannot
/// disconnect BLE, write SQLite, execute tools, mutate game state, read keys, or bypass the host.
@MainActor
protocol A10UltraComputeRuntime: AnyObject {
    var state: A10UltraComputeState { get }
    var manifest: A10UltraComputeManifest { get }

    func prepare() async throws
    func generateText(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult
    func execute(_ request: A10UltraComputeRequest) async throws -> A10UltraComputeResponse
    func applyBudget(_ budget: A10UltraComputeBudget)
    func cancel()
    func trimMemory()
    func unload()
}

extension A10UltraComputeRuntime {
    func execute(_ request: A10UltraComputeRequest) async throws -> A10UltraComputeResponse {
        throw A10UltraComputeError.unsupported(request.task)
    }
}

/// Language bridge that lets the future compute core take over the currently empty LingCore
/// inference slot without taking over LingCore orchestration, tool routing, or host authority.
@MainActor
final class A10UltraLanguageRuntimeAdapter: LocalTextModelRuntime {
    private let runtime: any A10UltraComputeRuntime

    init(runtime: any A10UltraComputeRuntime) {
        self.runtime = runtime
    }

    var backendName: String { "A10 Ultra Ω Compute" }

    var state: AgentRuntimeState {
        switch runtime.state {
        case .detached, .unloaded: return .unloaded
        case .loading: return .loading
        case .ready: return .ready
        case .computing: return .generating
        case .cooling: return .cooling
        case .failed: return .unavailable
        }
    }

    var manifest: LocalTextModelManifest? {
        LocalTextModelManifest(
            id: runtime.manifest.runtimeID,
            displayName: runtime.manifest.displayName,
            upstream: "A10 Ultra Ω compute runtime",
            license: "Runtime-provided",
            quantization: "runtime-defined",
            sha256: runtime.manifest.artifactDigest,
            byteCount: 0,
            contextLimit: 0,
            recommendedProfile: "A10-Ultra-Compute",
            minimumOS: "\(runtime.manifest.minimumOSMajor).0"
        )
    }

    func prepare() async throws {
        try await runtime.prepare()
    }

    func generate(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult {
        try await runtime.generateText(request: request, onToken: onToken)
    }

    func cancel() { runtime.cancel() }
    func trimMemory() { runtime.trimMemory() }
    func unload() { runtime.unload() }
}
