import XCTest
@testable import VeilLink

final class GomokuUniversalThreatV10Tests: XCTestCase {
    private func makeBoard(host: [Int], guest: [Int]) -> GomokuState {
        XCTAssertTrue(host.count == guest.count || host.count == guest.count + 1)
        var state = GomokuState()
        for k in host.indices {
            XCTAssertTrue(state.apply(index: host[k], actor: .host))
            if k < guest.count {
                XCTAssertTrue(state.apply(index: guest[k], actor: .guest))
            }
        }
        return state
    }

    private func transform(_ index: Int, symmetry: Int) -> Int {
        var row = index / 15
        var column = index % 15
        for _ in 0..<(symmetry % 4) {
            (row, column) = (column, 14 - row)
        }
        if symmetry >= 4 { column = 14 - column }
        return row * 15 + column
    }

    func testCrossingOpenThreesProveAllDefenderRepliesForBlack() {
        let host = [111, 113, 97, 127]
        let guest = [0, 14, 210, 224]
        for symmetry in 0..<8 {
            let board = makeBoard(
                host: host.map { transform($0, symmetry: symmetry) },
                guest: guest.map { transform($0, symmetry: symmetry) }
            )
            let move = transform(112, symmetry: symmetry)
            let certificate = GomokuUniversalThreatV10.provenThreeTurnOpener(
                in: board, for: .host, roots: [move],
                deadline: Date.timeIntervalSinceReferenceDate + 2,
                nodeCap: 10_000
            )
            XCTAssertEqual(certificate?.firstMove, move)
            XCTAssertEqual(certificate?.defenderRepliesChecked, 216)
        }
    }

    func testCrossingOpenThreesProveAllDefenderRepliesForWhite() {
        let host = [0, 14, 210, 224, 56]
        let guest = [111, 113, 97, 127]
        for symmetry in 0..<8 {
            let board = makeBoard(
                host: host.map { transform($0, symmetry: symmetry) },
                guest: guest.map { transform($0, symmetry: symmetry) }
            )
            let move = transform(112, symmetry: symmetry)
            let certificate = GomokuUniversalThreatV10.provenThreeTurnOpener(
                in: board, for: .guest, roots: [move],
                deadline: Date.timeIntervalSinceReferenceDate + 2,
                nodeCap: 10_000
            )
            XCTAssertEqual(certificate?.firstMove, move)
            XCTAssertEqual(certificate?.defenderRepliesChecked, 215)
        }
    }

    func testNeverProvesWhenOpponentHasImmediateFive() {
        let board = makeBoard(host: [111, 113, 97, 127], guest: [0, 1, 2, 3])
        XCTAssertNil(GomokuUniversalThreatV10.provenThreeTurnOpener(
            in: board, for: .host, roots: [112],
            deadline: Date.timeIntervalSinceReferenceDate + 2,
            nodeCap: 10_000
        ))
    }

    func testDoesNotConfuseOrdinaryThreeWithCertifiedWin() {
        let board = makeBoard(host: [110, 111, 20, 25], guest: [0, 14, 210, 224])
        XCTAssertNil(GomokuUniversalThreatV10.provenThreeTurnOpener(
            in: board, for: .host, roots: [112],
            deadline: Date.timeIntervalSinceReferenceDate + 2,
            nodeCap: 10_000
        ))
    }

    func testExpiredBudgetAndExhaustedNodeCapNeverClaimAWin() {
        let board = makeBoard(host: [111, 113, 97, 127], guest: [0, 14, 210, 224])
        XCTAssertNil(GomokuUniversalThreatV10.provenThreeTurnOpener(
            in: board, for: .host, roots: [112],
            deadline: Date.timeIntervalSinceReferenceDate - 1,
            nodeCap: 10_000
        ))
        XCTAssertNil(GomokuUniversalThreatV10.provenThreeTurnOpener(
            in: board, for: .host, roots: [112],
            deadline: Date.timeIntervalSinceReferenceDate + 2,
            nodeCap: 1
        ))
    }

    func testPreexistingImmediateWinIsReservedForMandatoryWinGate() {
        let board = makeBoard(host: [109, 110, 111, 112], guest: [0, 14, 210, 224])
        XCTAssertNil(GomokuUniversalThreatV10.provenThreeTurnOpener(
            in: board, for: .host, roots: [113],
            deadline: Date.timeIntervalSinceReferenceDate + 2,
            nodeCap: 10_000
        ))
    }
}
