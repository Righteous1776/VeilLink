import Foundation
import XCTest

/// Integration-level guards. These MUST be executed by Apple CI before promotion.
final class EclipseR14UnifiedTests: XCTestCase {
    final class ObservedLines: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [([Int], Int)] = []
        func add(_ path: [Int], nodes: Int) {
            lock.lock(); storage.append((path, nodes)); lock.unlock()
        }
        func snapshot() -> [([Int], Int)] {
            lock.lock(); defer { lock.unlock() }
            return storage
        }
    }

    func testR12AndR13ExperimentalFlagsDefaultOff() {
        let limits = VeilGomokuUnifiedSearch.Limits()
        XCTAssertFalse(limits.r12HorizonQuiescence)
        XCTAssertFalse(limits.r13IncrementalThreatIndexEnabled)
    }

    func testFrozenTrainedModelIsRetained() {
        XCTAssertEqual(EclipseTrainedOrdering.modelID, "ECLIPSE-R10-real-candidate-histgb-v1")
    }

    func testObservedPVSBranchesAreActualLegalSequence() throws {
        var cells = [UInt8](repeating: 0, count: 225)
        cells[112] = 1
        cells[113] = 2
        let position = try XCTUnwrap(VeilGomokuUnifiedSearch.Position(cells: cells, toMove: 1))
        let collector = ObservedLines()
        var limits = VeilGomokuUnifiedSearch.Limits()
        limits.maxDepth = 2
        limits.maxNodes = 8_000
        limits.maxMilliseconds = 1_500
        limits.width = 8
        limits.forcedLineDepth = 0
        let decision = VeilGomokuUnifiedSearch.decide(
            position,
            limits: limits,
            onExploredLine: { path, nodes in collector.add(path, nodes: nodes) }
        )
        let move = try XCTUnwrap(decision)
        XCTAssertTrue((0..<225).contains(move.index))
        XCTAssertEqual(cells[move.index], 0)
        for (path, nodes) in collector.snapshot() {
            XCTAssertTrue((1...3).contains(path.count))
            XCTAssertGreaterThan(nodes, 0)
            var temp = cells
            var next: UInt8 = 1
            for idx in path {
                XCTAssertTrue((0..<225).contains(idx))
                XCTAssertEqual(temp[idx], 0)
                temp[idx] = next
                next = next == 1 ? 2 : 1
            }
        }
    }
}
