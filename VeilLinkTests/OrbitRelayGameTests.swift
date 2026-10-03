import XCTest
@testable import VeilLink

final class OrbitRelayGameTests: XCTestCase {
    func testRelayPointIsDeterministic() {
        let first = OrbitRelayState.relayPoint(
            sessionID: "orbit-relay-determinism",
            index: 3
        )
        let second = OrbitRelayState.relayPoint(
            sessionID: "orbit-relay-determinism",
            index: 3
        )
        XCTAssertEqual(first, second)
        XCTAssertGreaterThanOrEqual(first.x, 0)
        XCTAssertLessThanOrEqual(first.x, OrbitRelayState.fieldWidth)
        XCTAssertGreaterThanOrEqual(first.y, 0)
        XCTAssertLessThanOrEqual(first.y, OrbitRelayState.fieldHeight)
    }

    func testSameMoveReplaysIdentically() {
        let sessionID = "orbit-relay-replay"
        let move = OrbitRelayMove(angle: 32, power: 48)
        var first = OrbitRelayState()
        var second = OrbitRelayState()

        XCTAssertTrue(first.apply(move: move, actor: .host, sessionID: sessionID))
        XCTAssertTrue(second.apply(move: move, actor: .host, sessionID: sessionID))
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.lastTurn, second.lastTurn)
    }

    func testTurnSwitchesAndFuelIsBounded() {
        let sessionID = "orbit-relay-turn"
        var state = OrbitRelayState()
        let beforeFuel = state.hostCraft.fuel

        XCTAssertTrue(
            state.apply(
                move: OrbitRelayMove(angle: 0, power: 24),
                actor: .host,
                sessionID: sessionID
            )
        )
        XCTAssertLessThan(state.hostCraft.fuel, beforeFuel)
        XCTAssertGreaterThanOrEqual(state.hostCraft.fuel, 0)
        if !state.isFinished {
            XCTAssertEqual(state.currentPlayer, .guest)
        }
    }

    func testBotReturnsRuleValidatedMove() throws {
        let sessionID = "orbit-relay-bot"
        var state = OrbitRelayState()
        XCTAssertTrue(
            state.apply(
                move: OrbitRelayMove(angle: 25, power: 35),
                actor: .host,
                sessionID: sessionID
            )
        )
        guard !state.isFinished else { return }

        let move = try XCTUnwrap(
            OrbitRelayBot.chooseMove(
                in: state,
                actor: .guest,
                sessionID: sessionID
            )
        )
        var probe = state
        XCTAssertTrue(probe.apply(move: move, actor: .guest, sessionID: sessionID))
    }

    func testInvalidTurnAndMoveAreRejected() {
        let sessionID = "orbit-relay-invalid"
        var state = OrbitRelayState()
        let original = state

        XCTAssertFalse(
            state.apply(
                move: OrbitRelayMove(angle: -1, power: 50),
                actor: .host,
                sessionID: sessionID
            )
        )
        XCTAssertFalse(
            state.apply(
                move: OrbitRelayMove(angle: 20, power: 50),
                actor: .guest,
                sessionID: sessionID
            )
        )
        XCTAssertEqual(state, original)
    }
}
