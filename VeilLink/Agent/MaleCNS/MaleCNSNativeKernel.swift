import Foundation

enum MaleCNSNativeKernelError: LocalizedError, Equatable {
    case invalidGraph
    case invalidInput
    case outputOverflow
    case kernelFailure(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidGraph: return "MaleCNS 原生图结构无效。"
        case .invalidInput: return "MaleCNS 原生计算输入无效。"
        case .outputOverflow: return "MaleCNS spike 输出缓冲区不足。"
        case .kernelFailure(let code): return "MaleCNS 原生内核失败：\(code)。"
        }
    }
}

/// Compact, allocation-stable CSR graph for the future VFLY runtime.
/// The graph is validated once before entering the hot loop.
struct MaleCNSNativeGraph: Sendable {
    let neuronCount: Int
    let offsets: [UInt32]
    let targets: [UInt32]
    let weights: [Float]

    init(neuronCount: Int, offsets: [UInt32], targets: [UInt32], weights: [Float]) throws {
        guard neuronCount > 0,
              neuronCount <= Int(UInt32.max),
              targets.count == weights.count,
              targets.count <= Int(UInt32.max),
              offsets.count == neuronCount + 1 else {
            throw MaleCNSNativeKernelError.invalidGraph
        }
        let code = offsets.withUnsafeBufferPointer { offsetsBuffer in
            targets.withUnsafeBufferPointer { targetsBuffer in
                vlfly_validate_csr(
                    UInt32(neuronCount),
                    UInt32(targets.count),
                    offsetsBuffer.baseAddress,
                    targetsBuffer.baseAddress
                )
            }
        }
        guard code == VFLY_KERNEL_OK else { throw MaleCNSNativeKernelError.invalidGraph }
        self.neuronCount = neuronCount
        self.offsets = offsets
        self.targets = targets
        self.weights = weights
    }
}

struct MaleCNSNativeEpisodeSummary: Equatable, Sendable {
    let executedSteps: Int
    let finalFiredCount: Int
    let totalSpikeCount: UInt64
}

struct MaleCNSNativeReadoutGroup: Equatable, Sendable {
    let name: String
    let neuronIndices: [UInt32]
}

/// Compact CSR-like membership map for readout groups. Groups may overlap: one neuron can appear
/// in multiple group membership ranges without changing the neural graph itself.
struct MaleCNSNativeReadoutMap: Equatable, Sendable {
    let names: [String]
    let offsets: [UInt32]
    let neurons: [UInt32]
    /// Inverted CSR used by the compact native episode path: neuron -> readout groups.
    let neuronGroupOffsets: [UInt32]
    let neuronGroups: [UInt32]

    init(groups: [MaleCNSNativeReadoutGroup], neuronCount: Int) throws {
        guard neuronCount > 0, !groups.isEmpty, groups.count <= Int(UInt32.max) else {
            throw MaleCNSNativeKernelError.invalidInput
        }
        var builtOffsets: [UInt32] = [0]
        var builtNeurons: [UInt32] = []
        builtNeurons.reserveCapacity(groups.reduce(0) { $0 + $1.neuronIndices.count })
        var membershipCounts = [Int](repeating: 0, count: neuronCount)

        for group in groups {
            for neuron in group.neuronIndices {
                guard Int(neuron) < neuronCount else { throw MaleCNSNativeKernelError.invalidGraph }
                builtNeurons.append(neuron)
                membershipCounts[Int(neuron)] += 1
            }
            guard builtNeurons.count <= Int(UInt32.max) else { throw MaleCNSNativeKernelError.invalidInput }
            builtOffsets.append(UInt32(builtNeurons.count))
        }

        var invertedOffsets = [UInt32](repeating: 0, count: neuronCount + 1)
        var running = 0
        for neuron in 0..<neuronCount {
            invertedOffsets[neuron] = UInt32(running)
            running += membershipCounts[neuron]
            guard running <= Int(UInt32.max) else { throw MaleCNSNativeKernelError.invalidInput }
        }
        invertedOffsets[neuronCount] = UInt32(running)
        var invertedGroups = [UInt32](repeating: 0, count: running)
        var cursors = invertedOffsets.dropLast().map(Int.init)
        for (groupIndex, group) in groups.enumerated() {
            for neuron in group.neuronIndices {
                let index = Int(neuron)
                let cursor = cursors[index]
                invertedGroups[cursor] = UInt32(groupIndex)
                cursors[index] += 1
            }
        }

        let validation = invertedOffsets.withUnsafeBufferPointer { offsetBuffer in
            invertedGroups.withUnsafeBufferPointer { groupBuffer in
                vlfly_validate_readout_csr(
                    UInt32(neuronCount),
                    UInt32(groups.count),
                    UInt32(invertedGroups.count),
                    offsetBuffer.baseAddress,
                    invertedGroups.isEmpty ? nil : groupBuffer.baseAddress
                )
            }
        }
        guard validation == VFLY_KERNEL_OK else { throw MaleCNSNativeKernelError.invalidGraph }

        names = groups.map(\.name)
        offsets = builtOffsets
        neurons = builtNeurons
        neuronGroupOffsets = invertedOffsets
        neuronGroups = invertedGroups
    }
}

struct MaleCNSNativeReadoutSnapshot: Equatable, Sendable {
    let names: [String]
    let spikeCounts: [UInt64]
}

struct MaleCNSNativeEpisodeReadoutResult: Equatable, Sendable {
    let summary: MaleCNSNativeEpisodeSummary
    let readout: MaleCNSNativeReadoutSnapshot
}

/// Stateful LIF sandbox over the A9-inspired native fused kernel.
/// It deliberately owns all buffers so one neural step performs no heap allocation in C.
final class MaleCNSNativeKernelRuntime: MaleCNSComputeConsumer, @unchecked Sendable {
    private(set) var budget: MaleCNSComputeBudget = .suspended
    private var voltage: [Float]
    private var currentScratch: [Float]
    private var externalDrive: [Float]
    private var firedInputStorage: [UInt32]
    private var firedInputCount: Int = 0
    private var firedOutputStorage: [UInt32]
    private var spikeCounts: [UInt32]?
    private var lastFiredCount: Int = 0

    let graph: MaleCNSNativeGraph

    init(graph: MaleCNSNativeGraph) {
        self.graph = graph
        voltage = [Float](repeating: 0, count: graph.neuronCount)
        currentScratch = [Float](repeating: 0, count: graph.neuronCount)
        externalDrive = [Float](repeating: 0, count: graph.neuronCount)
        firedInputStorage = [UInt32](repeating: 0, count: graph.neuronCount)
        firedOutputStorage = [UInt32](repeating: 0, count: graph.neuronCount)
        spikeCounts = nil
    }

    func applyComputeBudget(_ budget: MaleCNSComputeBudget) {
        self.budget = budget
        if budget.tier == .suspended {
            firedInputCount = 0
            lastFiredCount = 0
        }
    }

    func trimComputeState() {
        currentScratch.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        externalDrive.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        // Full per-neuron histograms are diagnostic/research state, not required by the compact
        // game/cognitive readout path. Drop them aggressively under trim/memory pressure.
        spikeCounts = nil
        firedInputCount = 0
        lastFiredCount = 0
    }

    func reset() {
        voltage.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        trimComputeState()
    }

    func setExternalDrive(_ drive: [Float]) throws {
        guard drive.count == graph.neuronCount else { throw MaleCNSNativeKernelError.invalidInput }
        externalDrive = drive
    }

    func clearExternalDrive() {
        externalDrive.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
    }

    /// One deterministic LIF step with allocation-stable spike buffers. Noise/refractory are
    /// intentionally not hidden here; a future reference runtime must provide those explicitly
    /// so graph/seed/version remain reproducible. The returned count indexes `firedSnapshot()`;
    /// callers that execute many consecutive neural steps should use this method and avoid
    /// materializing a Swift Array on every tick.
    @discardableResult
    func stepInPlace(
        decay: Float,
        gain: Float,
        tonic: Float,
        threshold: Float = 1.0
    ) throws -> Int {
        guard budget.tier != .suspended else {
            firedInputCount = 0
            lastFiredCount = 0
            return 0
        }

        // Capture every scalar before opening nested unsafe-buffer scopes. Besides avoiding
        // Swift exclusivity traps, this keeps the FFI boundary a single, predictable call.
        let neuronCount = UInt32(graph.neuronCount)
        let edgeCount = UInt32(graph.targets.count)
        let firedInCount = UInt32(firedInputCount)
        let firedOutCapacity = UInt32(firedOutputStorage.count)
        var produced: UInt32 = 0

        let status = graph.offsets.withUnsafeBufferPointer { offsetsBuffer in
            graph.targets.withUnsafeBufferPointer { targetsBuffer in
                graph.weights.withUnsafeBufferPointer { weightsBuffer in
                    firedInputStorage.withUnsafeBufferPointer { firedInputBuffer in
                        voltage.withUnsafeMutableBufferPointer { voltageBuffer in
                            currentScratch.withUnsafeMutableBufferPointer { currentBuffer in
                                externalDrive.withUnsafeBufferPointer { externalBuffer in
                                    firedOutputStorage.withUnsafeMutableBufferPointer { firedOutputBuffer in
                                        vlfly_lif_step_f32(
                                            neuronCount,
                                            edgeCount,
                                            offsetsBuffer.baseAddress,
                                            targetsBuffer.baseAddress,
                                            weightsBuffer.baseAddress,
                                            firedInCount == 0 ? nil : firedInputBuffer.baseAddress,
                                            firedInCount,
                                            voltageBuffer.baseAddress,
                                            currentBuffer.baseAddress,
                                            externalBuffer.baseAddress,
                                            decay,
                                            gain,
                                            tonic,
                                            threshold,
                                            firedOutputBuffer.baseAddress,
                                            firedOutCapacity,
                                            &produced
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        switch status {
        case Int32(VFLY_KERNEL_OK): break
        case Int32(VFLY_KERNEL_INVALID_ARGUMENT): throw MaleCNSNativeKernelError.invalidInput
        case Int32(VFLY_KERNEL_INVALID_GRAPH): throw MaleCNSNativeKernelError.invalidGraph
        case Int32(VFLY_KERNEL_OUTPUT_OVERFLOW): throw MaleCNSNativeKernelError.outputOverflow
        default: throw MaleCNSNativeKernelError.kernelFailure(status)
        }

        let count = min(Int(produced), firedOutputStorage.count)
        // Swap the two preallocated buffers. No spike array is allocated in the tick loop.
        swap(&firedInputStorage, &firedOutputStorage)
        firedInputCount = count
        lastFiredCount = count
        return count
    }

    /// Runs a bounded deterministic episode in one native call, amortizing the Swift/C boundary.
    /// `requestedSteps` is always clamped to the current A9 MaleCNS budget. Spike counts are
    /// accumulated in a preallocated UInt32 array for later readout-group aggregation.
    func runEpisode(
        requestedSteps: Int? = nil,
        decay: Float,
        gain: Float,
        tonic: Float,
        threshold: Float = 1.0
    ) throws -> MaleCNSNativeEpisodeSummary {
        guard budget.tier != .suspended else {
            return MaleCNSNativeEpisodeSummary(executedSteps: 0, finalFiredCount: 0, totalSpikeCount: 0)
        }
        let limit = max(0, budget.neuralStepBudget)
        let steps = min(max(0, requestedSteps ?? limit), limit)
        guard steps > 0 else {
            return MaleCNSNativeEpisodeSummary(
                executedSteps: 0,
                finalFiredCount: firedInputCount,
                totalSpikeCount: 0
            )
        }

        if spikeCounts == nil {
            spikeCounts = [UInt32](repeating: 0, count: graph.neuronCount)
        }
        spikeCounts?.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }

        let neuronCount = UInt32(graph.neuronCount)
        let edgeCount = UInt32(graph.targets.count)
        let spikeCapacity = UInt32(firedInputStorage.count)
        let stepCount = UInt32(steps)
        var firedCount = UInt32(firedInputCount)
        var totalSpikes: UInt64 = 0

        let status = graph.offsets.withUnsafeBufferPointer { offsetsBuffer in
            graph.targets.withUnsafeBufferPointer { targetsBuffer in
                graph.weights.withUnsafeBufferPointer { weightsBuffer in
                    firedInputStorage.withUnsafeMutableBufferPointer { spikeABuffer in
                        firedOutputStorage.withUnsafeMutableBufferPointer { spikeBBuffer in
                            voltage.withUnsafeMutableBufferPointer { voltageBuffer in
                                currentScratch.withUnsafeMutableBufferPointer { currentBuffer in
                                    externalDrive.withUnsafeBufferPointer { externalBuffer in
                                        spikeCounts!.withUnsafeMutableBufferPointer { spikeCountBuffer in
                                            vlfly_lif_run_f32(
                                                neuronCount,
                                                edgeCount,
                                                offsetsBuffer.baseAddress,
                                                targetsBuffer.baseAddress,
                                                weightsBuffer.baseAddress,
                                                spikeABuffer.baseAddress,
                                                spikeBBuffer.baseAddress,
                                                spikeCapacity,
                                                &firedCount,
                                                voltageBuffer.baseAddress,
                                                currentBuffer.baseAddress,
                                                externalBuffer.baseAddress,
                                                decay,
                                                gain,
                                                tonic,
                                                threshold,
                                                stepCount,
                                                spikeCountBuffer.baseAddress,
                                                &totalSpikes
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        switch status {
        case Int32(VFLY_KERNEL_OK): break
        case Int32(VFLY_KERNEL_INVALID_ARGUMENT): throw MaleCNSNativeKernelError.invalidInput
        case Int32(VFLY_KERNEL_INVALID_GRAPH): throw MaleCNSNativeKernelError.invalidGraph
        case Int32(VFLY_KERNEL_OUTPUT_OVERFLOW): throw MaleCNSNativeKernelError.outputOverflow
        default: throw MaleCNSNativeKernelError.kernelFailure(status)
        }

        let finalCount = min(Int(firedCount), firedInputStorage.count)
        firedInputCount = finalCount
        lastFiredCount = finalCount
        return MaleCNSNativeEpisodeSummary(
            executedSteps: steps,
            finalFiredCount: finalCount,
            totalSpikeCount: totalSpikes
        )
    }

    /// Runs one A9-bounded episode while accumulating only selected readout groups. Unlike the
    /// research/diagnostic `runEpisode`, this path does not write a neuron-count-sized spike-count
    /// array and is intended for game/cognitive decisions that consume compact descending readouts.
    func runEpisodeWithReadouts(
        using map: MaleCNSNativeReadoutMap,
        requestedSteps: Int? = nil,
        decay: Float,
        gain: Float,
        tonic: Float,
        threshold: Float = 1.0
    ) throws -> MaleCNSNativeEpisodeReadoutResult {
        guard budget.tier != .suspended else {
            return MaleCNSNativeEpisodeReadoutResult(
                summary: MaleCNSNativeEpisodeSummary(executedSteps: 0, finalFiredCount: 0, totalSpikeCount: 0),
                readout: MaleCNSNativeReadoutSnapshot(names: map.names, spikeCounts: [UInt64](repeating: 0, count: map.names.count))
            )
        }
        let limit = max(0, budget.neuralStepBudget)
        let steps = min(max(0, requestedSteps ?? limit), limit)
        guard steps > 0 else {
            return MaleCNSNativeEpisodeReadoutResult(
                summary: MaleCNSNativeEpisodeSummary(executedSteps: 0, finalFiredCount: firedInputCount, totalSpikeCount: 0),
                readout: MaleCNSNativeReadoutSnapshot(names: map.names, spikeCounts: [UInt64](repeating: 0, count: map.names.count))
            )
        }
        guard map.neuronGroupOffsets.count == graph.neuronCount + 1 else {
            throw MaleCNSNativeKernelError.invalidInput
        }

        let neuronCount = UInt32(graph.neuronCount)
        let edgeCount = UInt32(graph.targets.count)
        let spikeCapacity = UInt32(firedInputStorage.count)
        let stepCount = UInt32(steps)
        let groupCount = UInt32(map.names.count)
        let membershipCount = UInt32(map.neuronGroups.count)
        var firedCount = UInt32(firedInputCount)
        var totalSpikes: UInt64 = 0
        var groupTotals = [UInt64](repeating: 0, count: map.names.count)

        let status = graph.offsets.withUnsafeBufferPointer { offsetsBuffer in
            graph.targets.withUnsafeBufferPointer { targetsBuffer in
                graph.weights.withUnsafeBufferPointer { weightsBuffer in
                    firedInputStorage.withUnsafeMutableBufferPointer { spikeABuffer in
                        firedOutputStorage.withUnsafeMutableBufferPointer { spikeBBuffer in
                            voltage.withUnsafeMutableBufferPointer { voltageBuffer in
                                currentScratch.withUnsafeMutableBufferPointer { currentBuffer in
                                    externalDrive.withUnsafeBufferPointer { externalBuffer in
                                        map.neuronGroupOffsets.withUnsafeBufferPointer { readoutOffsetBuffer in
                                            map.neuronGroups.withUnsafeBufferPointer { readoutGroupBuffer in
                                                groupTotals.withUnsafeMutableBufferPointer { groupTotalBuffer in
                                                    vlfly_lif_run_readouts_f32(
                                                        neuronCount,
                                                        edgeCount,
                                                        offsetsBuffer.baseAddress,
                                                        targetsBuffer.baseAddress,
                                                        weightsBuffer.baseAddress,
                                                        spikeABuffer.baseAddress,
                                                        spikeBBuffer.baseAddress,
                                                        spikeCapacity,
                                                        &firedCount,
                                                        voltageBuffer.baseAddress,
                                                        currentBuffer.baseAddress,
                                                        externalBuffer.baseAddress,
                                                        decay,
                                                        gain,
                                                        tonic,
                                                        threshold,
                                                        stepCount,
                                                        groupCount,
                                                        readoutOffsetBuffer.baseAddress,
                                                        membershipCount == 0 ? nil : readoutGroupBuffer.baseAddress,
                                                        membershipCount,
                                                        groupTotalBuffer.baseAddress,
                                                        &totalSpikes
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        switch status {
        case Int32(VFLY_KERNEL_OK): break
        case Int32(VFLY_KERNEL_INVALID_ARGUMENT): throw MaleCNSNativeKernelError.invalidInput
        case Int32(VFLY_KERNEL_INVALID_GRAPH): throw MaleCNSNativeKernelError.invalidGraph
        case Int32(VFLY_KERNEL_OUTPUT_OVERFLOW): throw MaleCNSNativeKernelError.outputOverflow
        default: throw MaleCNSNativeKernelError.kernelFailure(status)
        }

        let finalCount = min(Int(firedCount), firedInputStorage.count)
        firedInputCount = finalCount
        lastFiredCount = finalCount
        return MaleCNSNativeEpisodeReadoutResult(
            summary: MaleCNSNativeEpisodeSummary(
                executedSteps: steps,
                finalFiredCount: finalCount,
                totalSpikeCount: totalSpikes
            ),
            readout: MaleCNSNativeReadoutSnapshot(names: map.names, spikeCounts: groupTotals)
        )
    }

    /// Whether the research/diagnostic full-neuron histogram is currently resident. Compact
    /// game/cognitive episodes keep this false and save neuronCount * 4 bytes.
    var hasPerNeuronSpikeCounts: Bool { spikeCounts != nil }

    /// Returns accumulated spike counts from the most recent full-count episode. Compact readout
    /// episodes intentionally do not materialize this array.
    func spikeCountSnapshot() -> [UInt32] { spikeCounts ?? [] }

    /// Reduces the most recent full episode's per-neuron counts into compact readout groups.
    /// code. This traverses only group memberships once per decision, never once per neural tick.
    func readoutSnapshot(using map: MaleCNSNativeReadoutMap) throws -> MaleCNSNativeReadoutSnapshot {
        guard map.offsets.count == map.names.count + 1 else { throw MaleCNSNativeKernelError.invalidInput }
        var totals = [UInt64](repeating: 0, count: map.names.count)
        let neuronCount = UInt32(graph.neuronCount)
        let groupCount = UInt32(map.names.count)
        let membershipCount = UInt32(map.neurons.count)
        guard let spikeCounts else { throw MaleCNSNativeKernelError.invalidInput }
        let status = spikeCounts.withUnsafeBufferPointer { spikeCountBuffer in
            map.offsets.withUnsafeBufferPointer { offsetBuffer in
                map.neurons.withUnsafeBufferPointer { neuronBuffer in
                    totals.withUnsafeMutableBufferPointer { totalBuffer in
                        vlfly_reduce_readouts_u32(
                            neuronCount,
                            spikeCountBuffer.baseAddress,
                            groupCount,
                            offsetBuffer.baseAddress,
                            membershipCount == 0 ? nil : neuronBuffer.baseAddress,
                            membershipCount,
                            totalBuffer.baseAddress
                        )
                    }
                }
            }
        }
        switch status {
        case Int32(VFLY_KERNEL_OK): break
        case Int32(VFLY_KERNEL_INVALID_ARGUMENT): throw MaleCNSNativeKernelError.invalidInput
        case Int32(VFLY_KERNEL_INVALID_GRAPH): throw MaleCNSNativeKernelError.invalidGraph
        default: throw MaleCNSNativeKernelError.kernelFailure(status)
        }
        return MaleCNSNativeReadoutSnapshot(names: map.names, spikeCounts: totals)
    }


    /// Convenience API for tests/diagnostics. It intentionally materializes a snapshot; production
    /// episode loops should prefer `stepInPlace` and read aggregate/readout values directly.
    func step(
        decay: Float,
        gain: Float,
        tonic: Float,
        threshold: Float = 1.0
    ) throws -> [UInt32] {
        _ = try stepInPlace(decay: decay, gain: gain, tonic: tonic, threshold: threshold)
        return firedSnapshot()
    }

    func firedSnapshot() -> [UInt32] {
        Array(firedInputStorage.prefix(lastFiredCount))
    }

    func voltageSnapshot() -> [Float] { voltage }
}
