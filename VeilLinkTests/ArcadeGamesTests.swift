import XCTest
@testable import VeilLink

final class ArcadeGamesTests: XCTestCase {
    private let artillerySessionID = "00000000-0000-0000-0000-000000000001"
    private let trailSessionID = "00000000-0000-0000-0000-000000000002"
    private let hockeySessionID = "00000000-0000-0000-0000-000000000003"

    func testArtillerySimulationIsDeterministicAndClampsPreviewInputs() {
        let first = ArtilleryState.simulate(
            angle: 48,
            power: 94,
            actor: .host,
            sessionID: artillerySessionID,
            turn: 0
        )
        let replay = ArtilleryState.simulate(
            angle: 48,
            power: 94,
            actor: .host,
            sessionID: artillerySessionID,
            turn: 0
        )
        let clamped = ArtilleryState.simulate(
            angle: 200,
            power: 1,
            actor: .host,
            sessionID: artillerySessionID,
            turn: 0
        )

        XCTAssertEqual(first, replay)
        XCTAssertEqual(clamped.angle, 80)
        XCTAssertEqual(clamped.power, 30)
        XCTAssertTrue((-12...12).contains(first.wind))
        XCTAssertTrue((0...ArtilleryState.worldWidth).contains(first.landingX))
        XCTAssertGreaterThan(first.damage, 0, "A maximum-range battlefield must still allow a real hit")
    }

    func testArtilleryRejectsInvalidOrOutOfTurnCommandsWithoutMutation() {
        var state = ArtilleryState()
        let initial = state

        XCTAssertFalse(state.apply(angle: 14, power: 80, actor: .host, sessionID: artillerySessionID))
        XCTAssertFalse(state.apply(angle: 45, power: 101, actor: .host, sessionID: artillerySessionID))
        XCTAssertFalse(state.apply(angle: 45, power: 80, actor: .guest, sessionID: artillerySessionID))
        XCTAssertEqual(state, initial)

        XCTAssertTrue(state.apply(angle: 48, power: 94, actor: .host, sessionID: artillerySessionID))
        let afterLegalShot = state
        XCTAssertFalse(state.apply(angle: 48, power: 94, actor: .host, sessionID: artillerySessionID))
        XCTAssertEqual(state, afterLegalShot)
    }

    func testArtilleryBotsOnlySubmitLegalShotsAndReachAWin() {
        var state = ArtilleryState()

        while state.winner == nil && !state.isDraw {
            let actor = state.currentPlayer
            guard let shot = ArtilleryBot.chooseShot(in: state, actor: actor, sessionID: artillerySessionID) else {
                return XCTFail("Bot must return a shot while the match is active")
            }
            XCTAssertTrue((15...80).contains(shot.angle))
            XCTAssertTrue((30...100).contains(shot.power))
            XCTAssertTrue(state.apply(angle: shot.angle, power: shot.power, actor: actor, sessionID: artillerySessionID))
        }

        XCTAssertEqual(state.winner, .host)
        XCTAssertFalse(state.isDraw)
        XCTAssertLessThanOrEqual(state.turn, ArtilleryState.maximumTurns)
        XCTAssertNil(ArtilleryBot.chooseShot(in: state, actor: state.currentPlayer, sessionID: artillerySessionID))
    }

    func testLightTrailCourseAndBotAreDeterministicAndLegal() {
        XCTAssertEqual(
            LightTrailState.obstacleLanes(sessionID: trailSessionID, round: 3),
            LightTrailState.obstacleLanes(sessionID: trailSessionID, round: 3)
        )
        XCTAssertEqual(
            LightTrailState.energyLane(sessionID: trailSessionID, round: 7),
            LightTrailState.energyLane(sessionID: trailSessionID, round: 7)
        )

        var state = LightTrailState()
        for _ in 0..<10 where state.winner == nil && !state.isDraw {
            let actor = state.currentPlayer
            guard let shift = LightTrailBot.chooseShift(in: state, actor: actor, sessionID: trailSessionID) else {
                return XCTFail("Bot must return a shift while the race is active")
            }
            XCTAssertTrue((-1...1).contains(shift))
            XCTAssertTrue((0..<LightTrailState.laneCount).contains(state.lane(for: actor) + shift))
            XCTAssertTrue(state.apply(shift: shift, actor: actor, sessionID: trailSessionID))
        }
    }

    func testLightTrailRejectsIllegalCommandsWithoutMutation() {
        var state = LightTrailState()
        let initial = state

        XCTAssertFalse(state.apply(shift: -2, actor: .host, sessionID: trailSessionID))
        XCTAssertFalse(state.apply(shift: 0, actor: .guest, sessionID: trailSessionID))
        XCTAssertEqual(state, initial)

        XCTAssertTrue(state.apply(shift: -1, actor: .host, sessionID: trailSessionID))
        XCTAssertTrue(state.apply(shift: 0, actor: .guest, sessionID: trailSessionID))
        XCTAssertTrue(state.apply(shift: -1, actor: .host, sessionID: trailSessionID))
        XCTAssertTrue(state.apply(shift: 0, actor: .guest, sessionID: trailSessionID))
        XCTAssertEqual(state.lane(for: .host), 0)
        let atBoundary = state
        XCTAssertFalse(state.apply(shift: -1, actor: .host, sessionID: trailSessionID))
        XCTAssertEqual(state, atBoundary)
    }

    func testLightTrailCollisionCanDecideTheWinner() {
        var state = LightTrailState()

        for round in 0..<3 {
            let hostLane = state.lane(for: .host)
            let obstacles = LightTrailState.obstacleLanes(sessionID: trailSessionID, round: round)
            let safeShift = (-1...1).first { shift in
                let destination = hostLane + shift
                return (0..<LightTrailState.laneCount).contains(destination) && !obstacles.contains(destination)
            }
            guard let safeShift else { return XCTFail("Every round must retain a navigable lane") }
            XCTAssertTrue(state.apply(shift: safeShift, actor: .host, sessionID: trailSessionID))
            XCTAssertTrue(state.apply(shift: 0, actor: .guest, sessionID: trailSessionID))
        }

        XCTAssertEqual(state.shield(for: .guest), 0)
        XCTAssertEqual(state.winner, .host)
        XCTAssertFalse(state.apply(shift: 0, actor: .host, sessionID: trailSessionID))
        XCTAssertNil(LightTrailBot.chooseShift(in: state, actor: .host, sessionID: trailSessionID))
    }

    func testArcadeStatesReplayIdenticallyFromTheSameCommands() {
        var artillery = ArtilleryState()
        var artilleryReplay = ArtilleryState()
        for _ in 0..<4 {
            let actor = artillery.currentPlayer
            guard let shot = ArtilleryBot.chooseShot(in: artillery, actor: actor, sessionID: artillerySessionID) else {
                return XCTFail("Expected a replayable artillery command")
            }
            XCTAssertTrue(artillery.apply(angle: shot.angle, power: shot.power, actor: actor, sessionID: artillerySessionID))
            XCTAssertTrue(artilleryReplay.apply(angle: shot.angle, power: shot.power, actor: actor, sessionID: artillerySessionID))
            XCTAssertEqual(artilleryReplay, artillery)
        }

        var trail = LightTrailState()
        var trailReplay = LightTrailState()
        for _ in 0..<8 {
            let actor = trail.currentPlayer
            guard let shift = LightTrailBot.chooseShift(in: trail, actor: actor, sessionID: trailSessionID) else {
                return XCTFail("Expected a replayable light-trail command")
            }
            XCTAssertTrue(trail.apply(shift: shift, actor: actor, sessionID: trailSessionID))
            XCTAssertTrue(trailReplay.apply(shift: shift, actor: actor, sessionID: trailSessionID))
            XCTAssertEqual(trailReplay, trail)
        }
    }

    func testEncryptedChatRecordsRebuildAllArcadeGames() throws {
        try assertOnlineRebuildsArtillery()
        try assertOnlineRebuildsLightTrail()
        try assertOnlineRebuildsMagneticHockey()
    }

    private func assertOnlineRebuildsArtillery() throws {
        let invite = MiniGamePacket(sessionID: artillerySessionID, game: .artillery, command: .invite, createdAt: Date(timeIntervalSince1970: 10))
        let accept = MiniGamePacket(sessionID: artillerySessionID, game: .artillery, command: .accept, createdAt: Date(timeIntervalSince1970: 11))
        var expected = ArtilleryState()
        guard let hostShot = ArtilleryBot.chooseShot(in: expected, actor: .host, sessionID: artillerySessionID) else {
            return XCTFail("Expected host shot")
        }
        XCTAssertTrue(expected.apply(angle: hostShot.angle, power: hostShot.power, actor: .host, sessionID: artillerySessionID))
        guard let guestShot = ArtilleryBot.chooseShot(in: expected, actor: .guest, sessionID: artillerySessionID) else {
            return XCTFail("Expected guest shot")
        }
        XCTAssertTrue(expected.apply(angle: guestShot.angle, power: guestShot.power, actor: .guest, sessionID: artillerySessionID))
        let moves = [
            MiniGamePacket(sessionID: artillerySessionID, game: .artillery, command: .move, turn: 0, move: .artillery(angle: hostShot.angle, power: hostShot.power), createdAt: Date(timeIntervalSince1970: 12)),
            MiniGamePacket(sessionID: artillerySessionID, game: .artillery, command: .move, turn: 1, move: .artillery(angle: guestShot.angle, power: guestShot.power), createdAt: Date(timeIntervalSince1970: 13))
        ]
        let snapshot = MiniGameSessionBuilder.session(
            id: artillerySessionID,
            from: try chatMessages(invite: invite, accept: accept, moves: moves)
        )
        XCTAssertEqual(snapshot?.artillery, expected)
        XCTAssertEqual(snapshot?.moveCount, 2)
        XCTAssertEqual(snapshot?.status, .active)
    }

    private func assertOnlineRebuildsLightTrail() throws {
        let invite = MiniGamePacket(sessionID: trailSessionID, game: .lightTrail, command: .invite, createdAt: Date(timeIntervalSince1970: 20))
        let accept = MiniGamePacket(sessionID: trailSessionID, game: .lightTrail, command: .accept, createdAt: Date(timeIntervalSince1970: 21))
        var expected = LightTrailState()
        let shifts = [-1, 0, 1, 0]
        var moves: [MiniGamePacket] = []
        for (turn, shift) in shifts.enumerated() {
            let actor = expected.currentPlayer
            XCTAssertTrue(expected.apply(shift: shift, actor: actor, sessionID: trailSessionID))
            moves.append(MiniGamePacket(
                sessionID: trailSessionID,
                game: .lightTrail,
                command: .move,
                turn: turn,
                move: .lightTrail(shift: shift),
                createdAt: Date(timeIntervalSince1970: TimeInterval(22 + turn))
            ))
        }
        let snapshot = MiniGameSessionBuilder.session(
            id: trailSessionID,
            from: try chatMessages(invite: invite, accept: accept, moves: moves)
        )
        XCTAssertEqual(snapshot?.lightTrail, expected)
        XCTAssertEqual(snapshot?.moveCount, shifts.count)
        XCTAssertEqual(snapshot?.status, .active)
    }

    private func assertOnlineRebuildsMagneticHockey() throws {
        let invite = MiniGamePacket(sessionID: hockeySessionID, game: .magneticHockey, command: .invite, createdAt: Date(timeIntervalSince1970: 30))
        let accept = MiniGamePacket(sessionID: hockeySessionID, game: .magneticHockey, command: .accept, createdAt: Date(timeIntervalSince1970: 31))
        let commands = [MagneticHockeyMove(angle: 0, power: 100), MagneticHockeyMove(angle: 180, power: 100)]
        var expected = MagneticHockeyState()
        var moves: [MiniGamePacket] = []
        for (turn, command) in commands.enumerated() {
            let actor = expected.currentPlayer
            XCTAssertTrue(expected.apply(move: command, actor: actor, sessionID: hockeySessionID))
            moves.append(MiniGamePacket(
                sessionID: hockeySessionID,
                game: .magneticHockey,
                command: .move,
                turn: turn,
                move: .magneticHockey(angle: command.angle, power: command.power),
                createdAt: Date(timeIntervalSince1970: TimeInterval(32 + turn))
            ))
        }
        let snapshot = MiniGameSessionBuilder.session(
            id: hockeySessionID,
            from: try chatMessages(invite: invite, accept: accept, moves: moves)
        )
        XCTAssertEqual(snapshot?.magneticHockey, expected)
        XCTAssertEqual(snapshot?.moveCount, commands.count)
        XCTAssertEqual(snapshot?.status, .active)
    }

    private func chatMessages(
        invite: MiniGamePacket,
        accept: MiniGamePacket,
        moves: [MiniGamePacket]
    ) throws -> [ChatMessage] {
        let conversationID = "arcade-tests"
        var messages = [
            ChatMessage(id: invite.actionID, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: invite.createdAt, isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: accept.actionID, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(accept), sentAt: accept.createdAt, isOutgoing: false, deliveryState: .delivered)
        ]
        messages += try moves.enumerated().map { offset, packet in
            let outgoing = offset.isMultiple(of: 2)
            return ChatMessage(
                id: packet.actionID,
                conversationID: conversationID,
                senderIdentityID: outgoing ? "host" : "guest",
                body: try MiniGameCodec.encode(packet),
                sentAt: packet.createdAt,
                isOutgoing: outgoing,
                deliveryState: .delivered
            )
        }
        return messages
    }
}
