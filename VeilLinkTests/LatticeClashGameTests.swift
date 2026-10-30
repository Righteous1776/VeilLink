import XCTest
@testable import VeilLink

final class LatticeClashGameTests: XCTestCase {
    func testInitialAnchorsAndLegalMoves() {
        let state = LatticeClashState()

        XCTAssertEqual(state.count(for: .host), 2)
        XCTAssertEqual(state.count(for: .guest), 2)
        XCTAssertEqual(state.currentPlayer, .host)
        XCTAssertFalse(state.legalMoves(for: .host).isEmpty)
        XCTAssertFalse(state.legalMoves(for: .guest).isEmpty)
    }

    func testRemotePlacementIsRejectedWithoutMutation() {
        var state = LatticeClashState()
        let original = state
        let center = LatticeClashState.index(row: 3, column: 3)

        XCTAssertFalse(
            state.apply(
                move: LatticeClashMove(index: center),
                actor: .host
            )
        )
        XCTAssertEqual(state, original)
    }

    func testThreeSideSupportCapturesEnemyNode() {
        var board = Array(
            repeating: LatticeClashCell.empty,
            count: LatticeClashState.cellCount
        )
        board[17] = .host
        board[23] = .host
        board[25] = .host
        board[24] = .guest

        var state = LatticeClashState(
            board: board,
            currentPlayer: .host
        )

        XCTAssertTrue(
            state.apply(
                move: LatticeClashMove(index: 31),
                actor: .host
            )
        )
        XCTAssertEqual(state.cell(at: 24), .host)
        XCTAssertEqual(state.lastTurn?.captured, [24])
    }

    func testIdenticalMoveSequenceProducesIdenticalState() {
        var first = LatticeClashState()
        var second = LatticeClashState()

        for _ in 0..<12 {
            guard !first.isFinished else { break }
            let actor = first.currentPlayer
            let move = first.legalMoves(for: actor).first

            XCTAssertEqual(actor, second.currentPlayer)
            XCTAssertEqual(move, second.legalMoves(for: actor).first)

            guard let move else { break }
            XCTAssertTrue(first.apply(move: move, actor: actor))
            XCTAssertTrue(second.apply(move: move, actor: actor))
            XCTAssertEqual(first, second)
        }
    }

    func testBotChoiceIsDeterministicAndRuleValidated() throws {
        let state = LatticeClashState()

        let first = try XCTUnwrap(
            LatticeClashBot.chooseMove(in: state, actor: .host)
        )
        let second = try XCTUnwrap(
            LatticeClashBot.chooseMove(in: state, actor: .host)
        )

        XCTAssertEqual(first, second)

        var probe = state
        XCTAssertTrue(probe.apply(move: first, actor: .host))
    }

    func testMajorityControlEndsGame() {
        var board = Array(
            repeating: LatticeClashCell.empty,
            count: LatticeClashState.cellCount
        )
        for index in 0..<24 {
            board[index] = .host
        }
        board[48] = .guest

        var state = LatticeClashState(
            board: board,
            currentPlayer: .host
        )

        XCTAssertTrue(
            state.apply(
                move: LatticeClashMove(index: 24),
                actor: .host
            )
        )
        XCTAssertEqual(state.count(for: .host), 25)
        XCTAssertEqual(state.winner, .host)
        XCTAssertTrue(state.isFinished)
    }

    func testWrongActorIsRejected() throws {
        var state = LatticeClashState()
        let original = state
        let guestMove = try XCTUnwrap(
            state.legalMoves(for: .guest).first
        )

        XCTAssertFalse(state.apply(move: guestMove, actor: .guest))
        XCTAssertEqual(state, original)
    }
}
