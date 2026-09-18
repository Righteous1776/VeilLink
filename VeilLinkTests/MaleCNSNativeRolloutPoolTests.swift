import XCTest
@testable import VeilLink

final class MaleCNSNativeRolloutPoolTests: XCTestCase {
    func testRolloutPoolUsesA9WorkerAndRolloutCapsWithoutChangingResults() throws {
        let graph = try MaleCNSNativeGraph(
            neuronCount: 4,
            offsets: [0, 1, 2, 3, 3],
            targets: [1, 2, 3],
            weights: [1, 1, 1]
        )
        let map = try MaleCNSNativeReadoutMap(groups: [
            MaleCNSNativeReadoutGroup(name: "motor", neuronIndices: [1, 2, 3]),
            MaleCNSNativeReadoutGroup(name: "terminal", neuronIndices: [3])
        ], neuronCount: 4)
        let pool = MaleCNSNativeRolloutPool(graph: graph, readoutMap: map)
        pool.applyComputeBudget(MaleCNSComputeBudget(
            tier: .core, workerCount: 3, neuralStepBudget: 4,
            episodeMilliseconds: 100, rolloutCount: 4, stateSampleStride: 1
        ))
        let requests = (0..<7).map { index in
            MaleCNSNativeRolloutRequest(
                id: index,
                externalDrive: [1.1, 0, 0, 0],
                requestedSteps: 4,
                decay: 0,
                gain: 1,
                tonic: 0
            )
        }
        let results = try pool.run(requests)
        XCTAssertEqual(results.map(\.id), [0, 1, 2, 3])
        XCTAssertEqual(pool.residentWorkerCount, 3)
        XCTAssertTrue(results.allSatisfy { $0.episode.readout.spikeCounts == [3, 1] })
        XCTAssertTrue(results.allSatisfy { $0.episode.summary.totalSpikeCount == 4 })

        pool.applyComputeBudget(.suspended)
        XCTAssertEqual(pool.residentWorkerCount, 0)
        XCTAssertTrue(try pool.run(requests).isEmpty)
    }

    func testSingleAndMultiWorkerRolloutsAreDeterministicallyEquivalent() throws {
        let graph = try MaleCNSNativeGraph(
            neuronCount: 6,
            offsets: [0, 2, 3, 4, 5, 5, 5],
            targets: [1, 2, 3, 4, 5],
            weights: [0.8, 0.5, 1, 1, 1]
        )
        let map = try MaleCNSNativeReadoutMap(groups: [
            MaleCNSNativeReadoutGroup(name: "all", neuronIndices: [0, 1, 2, 3, 4, 5]),
            MaleCNSNativeReadoutGroup(name: "tail", neuronIndices: [4, 5])
        ], neuronCount: 6)
        let requests = (0..<4).map { index in
            MaleCNSNativeRolloutRequest(
                id: index,
                externalDrive: [index.isMultiple(of: 2) ? 1.1 : 1.3, 0, 0, 0, 0, 0],
                requestedSteps: 6,
                decay: 0.2,
                gain: 1.4,
                tonic: 0.05
            )
        }

        func run(workers: Int) throws -> [MaleCNSNativeRolloutResult] {
            let pool = MaleCNSNativeRolloutPool(graph: graph, readoutMap: map)
            pool.applyComputeBudget(MaleCNSComputeBudget(
                tier: .core, workerCount: workers, neuralStepBudget: 6,
                episodeMilliseconds: 100, rolloutCount: 4, stateSampleStride: 1
            ))
            return try pool.run(requests)
        }

        XCTAssertEqual(try run(workers: 1), try run(workers: 4))
    }
}
