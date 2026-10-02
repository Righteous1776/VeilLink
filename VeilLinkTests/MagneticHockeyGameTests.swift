import XCTest
@testable import VeilLink

final class MagneticHockeyGameTests: XCTestCase {
    private let sessionID = "magnetic-hockey-replay"

    func testPhysicsAndMagneticFieldReplayDeterministically() {
        var first = MagneticHockeyState()
        var replay = MagneticHockeyState()
        let commands = [
            MagneticHockeyMove(angle: 32, power: 71),
            MagneticHockeyMove(angle: 207, power: 64),
            MagneticHockeyMove(angle: 349, power: 83),
            MagneticHockeyMove(angle: 161, power: 55)
        ]

        for command in commands {
            let actor = first.currentPlayer
            XCTAssertTrue(first.apply(move: command, actor: actor, sessionID: sessionID))
            XCTAssertTrue(replay.apply(move: command, actor: actor, sessionID: sessionID))
            XCTAssertEqual(replay, first)
        }

        XCTAssertEqual(
            MagneticHockeyState.fieldPolarity(sessionID: sessionID, turn: 7),
            MagneticHockeyState.fieldPolarity(sessionID: sessionID, turn: 7)
        )
        XCTAssertTrue((0...MagneticHockeyState.fieldWidth).contains(first.puckPosition.x))
        XCTAssertTrue((0...MagneticHockeyState.fieldHeight).contains(first.puckPosition.y))
    }

    func testIllegalInputAndOutOfTurnMoveDoNotMutateState() {
        var state = MagneticHockeyState()
        let initial = state

        XCTAssertFalse(state.apply(angle: -1, power: 50, actor: .host, sessionID: sessionID))
        XCTAssertFalse(state.apply(angle: 360, power: 50, actor: .host, sessionID: sessionID))
        XCTAssertFalse(state.apply(angle: 45, power: 9, actor: .host, sessionID: sessionID))
        XCTAssertFalse(state.apply(angle: 45, power: 101, actor: .host, sessionID: sessionID))
        XCTAssertFalse(state.apply(angle: 45, power: 50, actor: .guest, sessionID: sessionID))
        XCTAssertFalse(state.apply(angle: 45, power: 50, actor: .host, sessionID: ""))
        XCTAssertEqual(state, initial)

        XCTAssertTrue(state.apply(angle: 45, power: 50, actor: .host, sessionID: sessionID))
        let afterLegalMove = state
        XCTAssertFalse(state.apply(angle: 45, power: 50, actor: .host, sessionID: sessionID))
        XCTAssertEqual(state, afterLegalMove)
    }

    func testBotIsDeterministicAndReturnsAnApplyValidatedMove() {
        let state = MagneticHockeyState()
        let first = MagneticHockeyBot.chooseMove(in: state, actor: .host, sessionID: sessionID)
        let replay = MagneticHockeyBot.chooseMove(in: state, actor: .host, sessionID: sessionID)

        XCTAssertEqual(first, replay)
        guard let first else { return XCTFail("An active match must produce a bot move") }
        XCTAssertTrue((0..<360).contains(first.angle))
        XCTAssertTrue((10...100).contains(first.power))

        var applied = state
        XCTAssertTrue(applied.apply(move: first, actor: .host, sessionID: sessionID))
        XCTAssertNil(MagneticHockeyBot.chooseMove(in: state, actor: .guest, sessionID: sessionID))
    }

    func testStraightShotsCanScoreAndThreeGoalsEndTheMatch() {
        var state = MagneticHockeyState()

        XCTAssertTrue(state.apply(angle: 0, power: 100, actor: .host, sessionID: sessionID))
        XCTAssertEqual(state.hostScore, 1)
        XCTAssertEqual(state.lastShot?.scoredPlayer, .host)
        XCTAssertEqual(state.puckPosition, MagneticHockeyPoint(x: 500, y: 300))

        XCTAssertTrue(state.apply(angle: 180, power: 100, actor: .guest, sessionID: sessionID))
        XCTAssertEqual(state.guestScore, 1)
        XCTAssertTrue(state.apply(angle: 0, power: 100, actor: .host, sessionID: sessionID))
        XCTAssertTrue(state.apply(angle: 180, power: 100, actor: .guest, sessionID: sessionID))
        XCTAssertTrue(state.apply(angle: 0, power: 100, actor: .host, sessionID: sessionID))

        XCTAssertEqual(state.hostScore, MagneticHockeyState.winningScore)
        XCTAssertEqual(state.guestScore, 2)
        XCTAssertEqual(state.winner, .host)
        XCTAssertTrue(state.isFinished)
        XCTAssertFalse(state.isDraw)
        let finished = state
        XCTAssertFalse(state.apply(angle: 180, power: 100, actor: .guest, sessionID: sessionID))
        XCTAssertEqual(state, finished)
        XCTAssertNil(MagneticHockeyBot.chooseMove(in: state, actor: .guest, sessionID: sessionID))
    }

    func testTurnLimitUsesScoreToProduceAFiniteMatch() {
        let finiteSessionID = "magnetic-hockey-turn-limit"
        var state = MagneticHockeyState()
        XCTAssertTrue(state.apply(angle: 0, power: 100, actor: .host, sessionID: finiteSessionID))

        while state.turn < MagneticHockeyState.maximumTurns {
            let actor = state.currentPlayer
            let verticalAngle = actor == .host ? 90 : 270
            XCTAssertTrue(state.apply(angle: verticalAngle, power: 10, actor: actor, sessionID: finiteSessionID))
        }

        XCTAssertEqual(state.turn, MagneticHockeyState.maximumTurns)
        XCTAssertEqual(state.hostScore, 1)
        XCTAssertEqual(state.guestScore, 0)
        XCTAssertEqual(state.winner, .host)
        XCTAssertTrue(state.isFinished)
    }
}
