import Foundation

enum MaleCNSGraphTier: String, Sendable { case reference, core, lite }

struct MaleCNSGraphRuntimeProfile: Equatable, Sendable {
    let graphID: String
    let tier: MaleCNSGraphTier
    let neuronCount: Int
    let edgeCount: Int
    let sourceDataset: String
}

/// First VFLY-backed native runtime. It deliberately uses deterministic/no-noise validation mode;
/// the frozen graph is real MaleCNS-derived connectivity, while stochastic fly.ai noise remains a
/// separately versioned future encoder/runtime feature rather than hidden nondeterminism.
///
/// Threading contract:
/// - A9 budget updates are non-blocking and only publish desired state.
/// - Native kernel mutation is serialized behind `executionLock`.
/// - A budget change that arrives during an episode takes effect at the next bounded episode.
/// - trim requests never wait on the UI thread; if an episode is active they are applied before
///   the next native operation.
final class MaleCNSGraphRuntime: MaleCNSComputeConsumer, @unchecked Sendable {
    static let referenceDecay: Float = 0.8187307531 // exp(-0.020 / 0.100)
    static let referenceGain: Float = 3.0
    static let referenceTonic: Float = 0.14
    static let referenceThreshold: Float = 1.0

    let artifact: VFLY1Artifact
    let profile: MaleCNSGraphRuntimeProfile
    let encoder: MaleCNSStimulusEncoder
    let readoutMap: MaleCNSNativeReadoutMap

    private let kernel: MaleCNSNativeKernelRuntime
    private let stateLock = NSLock()
    private let executionLock = NSLock()
    private var desiredBudget: MaleCNSComputeBudget = .suspended
    private var trimRequested = false

    init(artifact: VFLY1Artifact, preferredReadouts: [String]? = nil) throws {
        guard artifact.metadata.datasetID == "male-cns:v1.0" else { throw VFLY1Error.invalidMetadata }
        guard let tier = MaleCNSGraphTier(rawValue: artifact.metadata.tier) else { throw VFLY1Error.invalidMetadata }
        self.artifact = artifact
        profile = MaleCNSGraphRuntimeProfile(
            graphID: artifact.metadata.graphID,
            tier: tier,
            neuronCount: artifact.graph.neuronCount,
            edgeCount: artifact.graph.targets.count,
            sourceDataset: artifact.metadata.datasetID
        )
        encoder = MaleCNSStimulusEncoder(artifact: artifact)
        readoutMap = try artifact.nativeReadoutMap(names: preferredReadouts)
        kernel = MaleCNSNativeKernelRuntime(graph: artifact.graph)
    }

    func applyComputeBudget(_ budget: MaleCNSComputeBudget) {
        stateLock.lock()
        desiredBudget = budget
        stateLock.unlock()
    }

    func trimComputeState() {
        stateLock.lock()
        trimRequested = true
        stateLock.unlock()

        // Best effort only: never block the caller (normally MainActor) behind a running episode.
        if executionLock.try() {
            defer { executionLock.unlock() }
            synchronizeKernelControlState()
        }
    }

    func run(stimulus: MaleCNSStimulus, requestedSteps: Int? = nil) throws -> MaleCNSNativeEpisodeReadoutResult {
        executionLock.lock()
        defer { executionLock.unlock() }
        synchronizeKernelControlState()
        kernel.reset()
        try kernel.setExternalDrive(encoder.drive(for: stimulus))
        return try kernel.runEpisodeWithReadouts(
            using: readoutMap,
            requestedSteps: requestedSteps,
            decay: Self.referenceDecay,
            gain: Self.referenceGain,
            tonic: Self.referenceTonic,
            threshold: Self.referenceThreshold
        )
    }

    /// Candidate-level R7 rollout over the exact same native LIF kernel. This accepts only the
    /// fixed eight-channel encoder output; it never mutates the frozen connectivity graph.
    func run(gameChannels: [Float], requestedSteps: Int? = nil) throws -> MaleCNSNativeEpisodeReadoutResult {
        executionLock.lock()
        defer { executionLock.unlock() }
        synchronizeKernelControlState()
        kernel.reset()
        try kernel.setExternalDrive(try encoder.drive(gameChannels: gameChannels))
        return try kernel.runEpisodeWithReadouts(
            using: readoutMap,
            requestedSteps: requestedSteps,
            decay: Self.referenceDecay,
            gain: Self.referenceGain,
            tonic: Self.referenceTonic,
            threshold: Self.referenceThreshold
        )
    }

    private func synchronizeKernelControlState() {
        stateLock.lock()
        let budget = desiredBudget
        let shouldTrim = trimRequested
        trimRequested = false
        stateLock.unlock()

        if shouldTrim { kernel.trimComputeState() }
        kernel.applyComputeBudget(budget)
    }
}
