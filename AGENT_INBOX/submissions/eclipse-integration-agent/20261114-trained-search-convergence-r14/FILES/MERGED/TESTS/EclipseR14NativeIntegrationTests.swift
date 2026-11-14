import XCTest
import Foundation
@testable import VeilLink

/// R14 integration regression; must be executed on Apple's iOS XCTest host.
/// This checks the merged Codex R10 + horizon R12 + threat-index R13 kernel
/// without enabling unvalidated experimental search flags.
final class EclipseR14NativeIntegrationTests: XCTestCase {
    final class CapturedBranches: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [([Int], Int)] = []
        func append(_ path: [Int], nodes: Int) {
            lock.lock(); defer { lock.unlock() }
            entries.append((path, nodes))
        }
        func snapshot() -> [([Int], Int)] {
            lock.lock(); defer { lock.unlock() }
            return entries
        }
    }

    func testResearchOptimizationsDefaultOff() {
        let limits = VeilGomokuUnifiedSearch.Limits()
        XCTAssertFalse(limits.r12HorizonQuiescence)
        XCTAssertFalse(limits.r13IncrementalThreatIndexEnabled)
    }

    func testRecordedNativeBranchesPreserveMoveChoice() throws {
        var cells = [UInt8](repeating: 0, count: 225)
        cells[112] = 1
        cells[113] = 2
        cells[97] = 1
        cells[98] = 2
        let p = try XCTUnwrap(VeilGomokuUnifiedSearch.Position(cells: cells, toMove: 1))
        var limits = VeilGomokuUnifiedSearch.Limits()
        limits.maxDepth = 2
        limits.width = 5
        limits.maxNodes = 8_000
        limits.maxMilliseconds = 10_000
        limits.forcedLineDepth = 0
        let uninstrumented = try XCTUnwrap(VeilGomokuUnifiedSearch.decide(
            p, limits: limits, trainedPolicy: true
        ))
        let observed = CapturedBranches()
        let instrumented = try XCTUnwrap(VeilGomokuUnifiedSearch.decide(
            p, limits: limits, trainedPolicy: true,
            onExploredLine: { indices, nodes in
                observed.append(indices, nodes: nodes)
            }
        ))
        XCTAssertEqual(uninstrumented.index, instrumented.index)
        XCTAssertEqual(uninstrumented.score, instrumented.score)
        XCTAssertEqual(uninstrumented.completedDepth, instrumented.completedDepth)
        XCTAssertTrue((0..<225).contains(instrumented.index))
        let events = observed.snapshot()
        XCTAssertFalse(events.isEmpty)
        for (path, nodes) in events {
            XCTAssertTrue((1...3).contains(path.count))
            XCTAssertGreaterThan(nodes, 0)
            var board = cells
            for index in path {
                XCTAssertTrue((0..<225).contains(index))
                XCTAssertEqual(board[index], 0)
                board[index] = board.filter { $0 != 0 }.count.isMultiple(of: 2) ? 1 : 2
            }
        }
    }

    func testNoModelReFitInMergedKernel() {
        // This is a rollback contract, not an Elo measurement.
        let disabled = VeilGomokuUnifiedSearch.Limits()
        XCTAssertFalse(disabled.r12HorizonQuiescence)
        XCTAssertFalse(disabled.r13IncrementalThreatIndexEnabled)
        let empty = [UInt8](repeating: 0, count: 225)
        XCTAssertNotNil(VeilGomokuUnifiedSearch.Position(cells: empty, toMove: 1))
        XCTAssertNil(VeilGomokuUnifiedSearch.Position(cells: empty + [0], toMove: 1))
    }
}
