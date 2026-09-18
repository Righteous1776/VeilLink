import Foundation

struct MaleCNSNativeRolloutRequest: Sendable, Equatable {
    let id: Int
    let externalDrive: [Float]
    let requestedSteps: Int?
    let decay: Float
    let gain: Float
    let tonic: Float
    let threshold: Float

    init(
        id: Int,
        externalDrive: [Float],
        requestedSteps: Int? = nil,
        decay: Float,
        gain: Float,
        tonic: Float,
        threshold: Float = 1.0
    ) {
        self.id = id
        self.externalDrive = externalDrive
        self.requestedSteps = requestedSteps
        self.decay = decay
        self.gain = gain
        self.tonic = tonic
        self.threshold = threshold
    }
}

struct MaleCNSNativeRolloutResult: Sendable, Equatable {
    let id: Int
    let episode: MaleCNSNativeEpisodeReadoutResult
}

private final class MaleCNSNativeRolloutAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var outputs: [MaleCNSNativeRolloutResult?]
    private var firstError: Error?

    init(count: Int) { outputs = [MaleCNSNativeRolloutResult?](repeating: nil, count: count) }

    func store(_ result: MaleCNSNativeRolloutResult, at index: Int) {
        lock.lock(); defer { lock.unlock() }
        outputs[index] = result
    }

    func record(_ error: Error) {
        lock.lock(); defer { lock.unlock() }
        if firstError == nil { firstError = error }
    }

    func finish() throws -> [MaleCNSNativeRolloutResult] {
        lock.lock(); defer { lock.unlock() }
        if let firstError { throw firstError }
        return outputs.compactMap { $0 }
    }
}

/// Deterministic A9-governed multi-rollout executor.
///
/// It deliberately parallelizes independent episodes rather than partitioning one connectome
/// timestep. That keeps each rollout's floating-point accumulation order identical to the
/// single-worker native kernel while allowing stronger devices to spend A9's worker budget on
/// candidate evaluation. The graph arrays are Swift COW values shared by every worker; only
/// voltage/current/spike state is private per runtime.
final class MaleCNSNativeRolloutPool: MaleCNSComputeConsumer, @unchecked Sendable {
    private let graph: MaleCNSNativeGraph
    private let readoutMap: MaleCNSNativeReadoutMap
    private let stateLock = NSLock()
    private var budget: MaleCNSComputeBudget = .suspended
    private var runtimes: [MaleCNSNativeKernelRuntime] = []

    init(graph: MaleCNSNativeGraph, readoutMap: MaleCNSNativeReadoutMap) {
        self.graph = graph
        self.readoutMap = readoutMap
    }

    func applyComputeBudget(_ budget: MaleCNSComputeBudget) {
        // Do not mutate worker runtime state from the governor thread while a rollout is in flight.
        // Each run takes one immutable budget snapshot; a later suspend is observed between
        // candidates. Dropping pool ownership is safe because active workers hold local refs.
        stateLock.lock()
        self.budget = budget
        if budget.tier == .suspended { runtimes.removeAll(keepingCapacity: false) }
        stateLock.unlock()
    }

    func trimComputeState() {
        // Releasing the pool references is race-safe: an in-flight run owns its worker references
        // until the bounded native episode returns, after which ARC reclaims their buffers.
        stateLock.lock()
        runtimes.removeAll(keepingCapacity: false)
        stateLock.unlock()
    }

    var residentWorkerCount: Int {
        stateLock.lock(); defer { stateLock.unlock() }
        return runtimes.count
    }

    func run(_ requests: [MaleCNSNativeRolloutRequest]) throws -> [MaleCNSNativeRolloutResult] {
        let budgetSnapshot = currentBudget()
        guard budgetSnapshot.tier != .suspended,
              budgetSnapshot.workerCount > 0,
              budgetSnapshot.rolloutCount > 0,
              !requests.isEmpty else { return [] }

        let acceptedCount = min(requests.count, budgetSnapshot.rolloutCount)
        let accepted = Array(requests.prefix(acceptedCount))
        for request in accepted where request.externalDrive.count != graph.neuronCount {
            throw MaleCNSNativeKernelError.invalidInput
        }

        let workerCount = max(1, min(budgetSnapshot.workerCount, acceptedCount))
        let workers = prepareWorkers(count: workerCount, budget: budgetSnapshot)
        let accumulator = MaleCNSNativeRolloutAccumulator(count: acceptedCount)

        let executeWorker: @Sendable (Int) -> Void = { [self] workerIndex in
            let runtime = workers[workerIndex]
            var requestIndex = workerIndex
            while requestIndex < acceptedCount {
                if currentBudget().tier == .suspended { break }
                let request = accepted[requestIndex]
                do {
                    runtime.reset()
                    runtime.applyComputeBudget(budgetSnapshot)
                    try runtime.setExternalDrive(request.externalDrive)
                    let episode = try runtime.runEpisodeWithReadouts(
                        using: readoutMap,
                        requestedSteps: request.requestedSteps,
                        decay: request.decay,
                        gain: request.gain,
                        tonic: request.tonic,
                        threshold: request.threshold
                    )
                    accumulator.store(
                        MaleCNSNativeRolloutResult(id: request.id, episode: episode),
                        at: requestIndex
                    )
                } catch {
                    accumulator.record(error)
                    break
                }
                requestIndex += workerCount
            }
        }

        if workerCount == 1 {
            executeWorker(0)
        } else {
            DispatchQueue.concurrentPerform(iterations: workerCount, execute: executeWorker)
        }

        return try accumulator.finish()
    }

    private func currentBudget() -> MaleCNSComputeBudget {
        stateLock.lock(); defer { stateLock.unlock() }
        return budget
    }

    private func prepareWorkers(count: Int, budget: MaleCNSComputeBudget) -> [MaleCNSNativeKernelRuntime] {
        stateLock.lock()
        while runtimes.count < count { runtimes.append(MaleCNSNativeKernelRuntime(graph: graph)) }
        if runtimes.count > count { runtimes.removeLast(runtimes.count - count) }
        let active = runtimes
        stateLock.unlock()
        for runtime in active { runtime.applyComputeBudget(budget) }
        return active
    }
}
