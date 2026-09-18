import XCTest
@testable import VeilLink

final class MaleCNSNativeKernelTests: XCTestCase {
    func testNativeEpisodeMatchesExpectedPropagationAndReadout() throws {
        let graph = try MaleCNSNativeGraph(
            neuronCount: 3,
            offsets: [0, 1, 2, 2],
            targets: [1, 2],
            weights: [1, 1]
        )
        let runtime = MaleCNSNativeKernelRuntime(graph: graph)
        runtime.applyComputeBudget(MaleCNSComputeBudget(
            tier: .lite,
            workerCount: 1,
            neuralStepBudget: 4,
            episodeMilliseconds: 100,
            rolloutCount: 1,
            stateSampleStride: 1
        ))
        try runtime.setExternalDrive([1.1, 0, 0])
        XCTAssertEqual(try runtime.stepInPlace(decay: 0, gain: 1, tonic: 0), 1)
        XCTAssertEqual(runtime.firedSnapshot(), [0])
        runtime.clearExternalDrive()

        let summary = try runtime.runEpisode(requestedSteps: 3, decay: 0, gain: 1, tonic: 0)
        XCTAssertEqual(summary.executedSteps, 3)
        XCTAssertEqual(summary.totalSpikeCount, 2)
        XCTAssertEqual(runtime.spikeCountSnapshot(), [0, 1, 1])

        let map = try MaleCNSNativeReadoutMap(groups: [
            MaleCNSNativeReadoutGroup(name: "motor", neuronIndices: [1, 2]),
            MaleCNSNativeReadoutGroup(name: "terminal", neuronIndices: [2]),
            MaleCNSNativeReadoutGroup(name: "overlap", neuronIndices: [1, 2, 2])
        ], neuronCount: 3)
        let readout = try runtime.readoutSnapshot(using: map)
        XCTAssertEqual(readout.names, ["motor", "terminal", "overlap"])
        XCTAssertEqual(readout.spikeCounts, [2, 1, 3])
    }

    func testA9BudgetClampsNativeEpisodeAndSuspensionStopsIt() throws {
        let graph = try MaleCNSNativeGraph(neuronCount: 1, offsets: [0, 0], targets: [], weights: [])
        let runtime = MaleCNSNativeKernelRuntime(graph: graph)
        runtime.applyComputeBudget(MaleCNSComputeBudget(
            tier: .lite,
            workerCount: 1,
            neuralStepBudget: 2,
            episodeMilliseconds: 50,
            rolloutCount: 1,
            stateSampleStride: 1
        ))
        try runtime.setExternalDrive([2])
        let bounded = try runtime.runEpisode(requestedSteps: 100, decay: 0, gain: 1, tonic: 0)
        XCTAssertEqual(bounded.executedSteps, 2)
        XCTAssertEqual(bounded.totalSpikeCount, 2)

        runtime.applyComputeBudget(.suspended)
        let stopped = try runtime.runEpisode(requestedSteps: 100, decay: 0, gain: 1, tonic: 0)
        XCTAssertEqual(stopped.executedSteps, 0)
    }
    func testCompactNativeReadoutEpisodeMatchesFullSpikeCountingPath() throws {
        let graph = try MaleCNSNativeGraph(
            neuronCount: 4,
            offsets: [0, 1, 2, 3, 3],
            targets: [1, 2, 3],
            weights: [1, 1, 1]
        )
        let budget = MaleCNSComputeBudget(
            tier: .lite, workerCount: 1, neuralStepBudget: 4,
            episodeMilliseconds: 100, rolloutCount: 1, stateSampleStride: 1
        )
        let map = try MaleCNSNativeReadoutMap(groups: [
            MaleCNSNativeReadoutGroup(name: "motor", neuronIndices: [1, 2, 3]),
            MaleCNSNativeReadoutGroup(name: "terminal", neuronIndices: [3]),
            MaleCNSNativeReadoutGroup(name: "overlap", neuronIndices: [2, 3, 3])
        ], neuronCount: 4)

        func primedRuntime() throws -> MaleCNSNativeKernelRuntime {
            let runtime = MaleCNSNativeKernelRuntime(graph: graph)
            runtime.applyComputeBudget(budget)
            try runtime.setExternalDrive([1.1, 0, 0, 0])
            XCTAssertEqual(try runtime.stepInPlace(decay: 0, gain: 1, tonic: 0), 1)
            runtime.clearExternalDrive()
            return runtime
        }

        let full = try primedRuntime()
        XCTAssertFalse(full.hasPerNeuronSpikeCounts)
        let fullSummary = try full.runEpisode(requestedSteps: 3, decay: 0, gain: 1, tonic: 0)
        XCTAssertTrue(full.hasPerNeuronSpikeCounts)
        let fullReadout = try full.readoutSnapshot(using: map)

        let compact = try primedRuntime()
        XCTAssertFalse(compact.hasPerNeuronSpikeCounts)
        let compactResult = try compact.runEpisodeWithReadouts(
            using: map, requestedSteps: 3, decay: 0, gain: 1, tonic: 0
        )

        XCTAssertEqual(compactResult.summary, fullSummary)
        XCTAssertEqual(compactResult.readout, fullReadout)
        XCTAssertFalse(compact.hasPerNeuronSpikeCounts)
        XCTAssertEqual(compact.firedSnapshot(), full.firedSnapshot())
        XCTAssertEqual(compact.voltageSnapshot(), full.voltageSnapshot())
        full.trimComputeState()
        XCTAssertFalse(full.hasPerNeuronSpikeCounts)
    }

}
