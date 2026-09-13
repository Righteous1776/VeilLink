import XCTest
@testable import VeilLink

final class MiniGameTests: XCTestCase {
    func testCodecRoundTripAndPreview() throws {
        let packet = MiniGamePacket(game: .gomoku, command: .invite)
        let encoded = try MiniGameCodec.encode(packet)
        XCTAssertEqual(MiniGameCodec.decode(encoded), packet)
        XCTAssertEqual(MiniGameCodec.previewText(for: encoded), "[小游戏] 邀请你玩五子棋")
    }

    func testGomokuDetectsFiveInRow() {
        var state = GomokuState()
        for col in 0..<4 {
            XCTAssertTrue(state.apply(index: col, actor: .host))
            XCTAssertTrue(state.apply(index: GomokuState.size + col, actor: .guest))
        }
        XCTAssertTrue(state.apply(index: 4, actor: .host))
        XCTAssertEqual(state.winner, .host)
    }

    func testXiangqiSoldierAndTurnValidation() {
        var state = XiangqiState()
        let redSoldier = 6 * XiangqiState.columns
        XCTAssertTrue(state.legalDestinations(from: redSoldier, actor: .host).contains(5 * XiangqiState.columns))
        XCTAssertFalse(state.legalDestinations(from: redSoldier, actor: .host).contains(redSoldier + 1))
        XCTAssertTrue(state.apply(from: redSoldier, to: 5 * XiangqiState.columns, actor: .host))
        XCTAssertEqual(state.currentPlayer, .guest)
        XCTAssertFalse(state.apply(from: 5 * XiangqiState.columns, to: 4 * XiangqiState.columns, actor: .host))
    }

    func testLudoRejectsWrongPlayerAndAdvancesTurn() {
        let sessionID = UUID().uuidString
        var state = LudoState()
        XCTAssertFalse(state.apply(pieceIndex: 0, actor: .guest, sessionID: sessionID))
        let legal = state.legalPieces(sessionID: sessionID)
        XCTAssertTrue(state.apply(pieceIndex: legal.first ?? -1, actor: .host, sessionID: sessionID))
        XCTAssertEqual(state.turn, 1)
    }

    func testSessionRebuildUsesEncryptedChatRecords() throws {
        let conversationID = UUID().uuidString
        let invite = MiniGamePacket(game: .gomoku, command: .invite)
        let accept = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .accept)
        let move = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 112))

        let messages = [
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: Date(), isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(accept), sentAt: Date().addingTimeInterval(1), isOutgoing: false, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(move), sentAt: Date().addingTimeInterval(2), isOutgoing: true, deliveryState: .delivered)
        ]

        let snapshot = MiniGameSessionBuilder.session(id: invite.sessionID, from: messages)
        XCTAssertEqual(snapshot?.status, .active)
        XCTAssertEqual(snapshot?.gomoku?.value(at: 112), 1)
        XCTAssertEqual(snapshot?.moveCount, 1)
    }

    func testSessionIndexMatchesTargetedReconstruction() throws {
        let conversationID = UUID().uuidString
        let first = MiniGamePacket(game: .gomoku, command: .invite)
        let second = MiniGamePacket(game: .tactical, command: .invite)
        let normalMessage = ChatMessage(
            id: UUID().uuidString,
            conversationID: conversationID,
            senderIdentityID: "host",
            body: "ordinary encrypted chat text",
            sentAt: Date(),
            isOutgoing: true,
            deliveryState: .delivered
        )
        let messages = [
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(first), sentAt: Date(), isOutgoing: true, deliveryState: .delivered),
            normalMessage,
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(second), sentAt: Date().addingTimeInterval(1), isOutgoing: false, deliveryState: .delivered)
        ]

        let index = MiniGameSessionBuilder.sessionsByID(from: messages)
        XCTAssertEqual(Set(index.keys), Set([first.sessionID, second.sessionID]))
        XCTAssertEqual(index[first.sessionID], MiniGameSessionBuilder.session(id: first.sessionID, from: messages))
        XCTAssertEqual(index[second.sessionID], MiniGameSessionBuilder.session(id: second.sessionID, from: messages))
    }
    func testGomokuWinningLineIsRecoverableForRendering() {
        var state = GomokuState()
        for col in 0..<4 {
            XCTAssertTrue(state.apply(index: 7 * GomokuState.size + col, actor: .host))
            XCTAssertTrue(state.apply(index: 6 * GomokuState.size + col, actor: .guest))
        }
        XCTAssertTrue(state.apply(index: 7 * GomokuState.size + 4, actor: .host))
        XCTAssertEqual(state.winningLine, (0..<5).map { 7 * GomokuState.size + $0 })
        XCTAssertFalse(state.isDraw)
    }

    func testSessionIgnoresMoveSentBeforeInvitationWasAccepted() throws {
        let conversationID = UUID().uuidString
        let invite = MiniGamePacket(game: .gomoku, command: .invite, createdAt: Date(timeIntervalSince1970: 10))
        let premature = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 112), createdAt: Date(timeIntervalSince1970: 11))
        let accept = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .accept, createdAt: Date(timeIntervalSince1970: 12))
        let messages = [
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: Date(timeIntervalSince1970: 10), isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(premature), sentAt: Date(timeIntervalSince1970: 11), isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(accept), sentAt: Date(timeIntervalSince1970: 12), isOutgoing: false, deliveryState: .delivered)
        ]
        let snapshot = MiniGameSessionBuilder.session(id: invite.sessionID, from: messages)
        XCTAssertEqual(snapshot?.status, .active)
        XCTAssertEqual(snapshot?.moveCount, 0)
        XCTAssertEqual(snapshot?.gomoku?.value(at: 112), 0)
    }

    func testHostCanCancelPendingInvitationWithoutStartingGame() throws {
        let conversationID = UUID().uuidString
        let invite = MiniGamePacket(game: .xiangqi, command: .invite, createdAt: Date(timeIntervalSince1970: 20))
        let cancel = MiniGamePacket(sessionID: invite.sessionID, game: .xiangqi, command: .resign, turn: 0, createdAt: Date(timeIntervalSince1970: 21))
        let messages = [
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: Date(timeIntervalSince1970: 20), isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(cancel), sentAt: Date(timeIntervalSince1970: 21), isOutgoing: true, deliveryState: .delivered)
        ]
        XCTAssertEqual(MiniGameSessionBuilder.session(id: invite.sessionID, from: messages)?.status, .cancelled)
    }

    func testLudoCaptureMetadataAndFinishedCountersStayConsistent() {
        let sessionID = UUID().uuidString
        var state = LudoState()
        XCTAssertEqual(state.finishedCount(for: .host), 0)
        XCTAssertEqual(state.finishedCount(for: .guest), 0)
        XCTAssertTrue((1...6).contains(state.expectedDice(sessionID: sessionID)))
        XCTAssertEqual(state.lastCapturedCount, 0)
        XCTAssertFalse(state.lastMoveGrantedExtraTurn)
    }

    func testStatisticsAggregateLocalOutcomesAndWinStreak() {
        let now = Date(timeIntervalSince1970: 100)
        func snapshot(id: String, game: MiniGameKind, status: MiniGameSessionStatus, activity: TimeInterval) -> MiniGameSessionSnapshot {
            MiniGameSessionSnapshot(
                id: id,
                game: game,
                hostIsLocal: true,
                status: status,
                invitedAt: now,
                startedAt: now,
                lastActivity: now.addingTimeInterval(activity),
                gomoku: game == .gomoku ? GomokuState() : nil,
                xiangqi: game == .xiangqi ? XiangqiState() : nil,
                ludo: game == .ludo ? LudoState() : nil,
                endedByResignation: false
            )
        }
        let sessions = [
            snapshot(id: "a", game: .gomoku, status: .finished(winner: .host), activity: 40),
            snapshot(id: "b", game: .xiangqi, status: .finished(winner: .host), activity: 30),
            snapshot(id: "c", game: .ludo, status: .finished(winner: nil), activity: 20),
            snapshot(id: "d", game: .gomoku, status: .finished(winner: .guest), activity: 10)
        ]
        let stats = MiniGameStatistics(sessions: sessions)
        XCTAssertEqual(stats.completed, 4)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.draws, 1)
        XCTAssertEqual(stats.currentWinStreak, 2)
        XCTAssertEqual(stats.byGame[.gomoku]?.completed, 2)
        XCTAssertEqual(stats.byGame[.gomoku]?.wins, 1)
        XCTAssertEqual(stats.winRate, 0.5, accuracy: 0.0001)
    }

    func testReplayBuildsDeterministicFramesFromEncryptedHistory() throws {
        let conversationID = UUID().uuidString
        let base = Date(timeIntervalSince1970: 1_000)
        let invite = MiniGamePacket(game: .gomoku, command: .invite, createdAt: base)
        let accept = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .accept, createdAt: base.addingTimeInterval(1))
        let move1 = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 112), createdAt: base.addingTimeInterval(2))
        let move2 = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 1, move: .gomoku(index: 113), createdAt: base.addingTimeInterval(3))
        let messages = [
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: base, isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(accept), sentAt: base.addingTimeInterval(1), isOutgoing: false, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(move1), sentAt: base.addingTimeInterval(2), isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(move2), sentAt: base.addingTimeInterval(3), isOutgoing: false, deliveryState: .delivered)
        ]
        let frames = MiniGameSessionBuilder.replay(sessionID: invite.sessionID, from: messages)
        XCTAssertEqual(frames.map(\.label), ["邀请对局", "对局开始", "第 1 手", "第 2 手"])
        XCTAssertEqual(frames.last?.snapshot.moveCount, 2)
        XCTAssertEqual(frames.last?.snapshot.gomoku?.value(at: 112), 1)
        XCTAssertEqual(frames.last?.snapshot.gomoku?.value(at: 113), 2)
        XCTAssertEqual(frames.last?.snapshot.duration ?? -1, 2, accuracy: 0.001)
    }

    func testRejectedLatePacketDoesNotRewriteEffectiveLastActivity() throws {
        let conversationID = UUID().uuidString
        let base = Date(timeIntervalSince1970: 2_000)
        let invite = MiniGamePacket(game: .gomoku, command: .invite, createdAt: base)
        let accept = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .accept, createdAt: base.addingTimeInterval(1))
        let legal = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 112), createdAt: base.addingTimeInterval(2))
        let impossibleLate = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 113), createdAt: base.addingTimeInterval(500))
        let messages = [
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: base, isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(accept), sentAt: base.addingTimeInterval(1), isOutgoing: false, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(legal), sentAt: base.addingTimeInterval(2), isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(impossibleLate), sentAt: base.addingTimeInterval(500), isOutgoing: true, deliveryState: .delivered)
        ]
        let snapshot = MiniGameSessionBuilder.session(id: invite.sessionID, from: messages)
        XCTAssertEqual(snapshot?.moveCount, 1)
        XCTAssertEqual(snapshot?.lastActivity, base.addingTimeInterval(2))
    }

    func testXiangqiThreefoldRepetitionEndsAsDraw() {
        var state = XiangqiState()
        let redHorseHome = 9 * XiangqiState.columns + 1
        let redHorseOut = 7 * XiangqiState.columns + 2
        let blackHorseHome = 1
        let blackHorseOut = 2 * XiangqiState.columns + 2

        for cycle in 0..<2 {
            XCTAssertTrue(state.apply(from: redHorseHome, to: redHorseOut, actor: .host), "red out cycle \(cycle)")
            XCTAssertTrue(state.apply(from: blackHorseHome, to: blackHorseOut, actor: .guest), "black out cycle \(cycle)")
            XCTAssertTrue(state.apply(from: redHorseOut, to: redHorseHome, actor: .host), "red home cycle \(cycle)")
            XCTAssertTrue(state.apply(from: blackHorseOut, to: blackHorseHome, actor: .guest), "black home cycle \(cycle)")
        }

        XCTAssertTrue(state.isDraw)
        XCTAssertEqual(state.drawReason, .threefoldRepetition)
        XCTAssertEqual(state.currentPositionRepetitionCount, 3)
        XCTAssertNil(state.winner)
        XCTAssertTrue(state.legalDestinations(from: redHorseHome, actor: .host).isEmpty)
    }

    func testSessionRebuildIsStableUnderDuplicateAndReorderedGameplayPackets() throws {
        let conversationID = UUID().uuidString
        let base = Date(timeIntervalSince1970: 3_000)
        let invite = MiniGamePacket(game: .gomoku, command: .invite, createdAt: base)
        let accept = MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .accept, createdAt: base.addingTimeInterval(1))
        let moves = [
            MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 0, move: .gomoku(index: 112), createdAt: base.addingTimeInterval(2)),
            MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 1, move: .gomoku(index: 113), createdAt: base.addingTimeInterval(3)),
            MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 2, move: .gomoku(index: 97), createdAt: base.addingTimeInterval(4)),
            MiniGamePacket(sessionID: invite.sessionID, game: .gomoku, command: .move, turn: 3, move: .gomoku(index: 98), createdAt: base.addingTimeInterval(5))
        ]

        func message(_ packet: MiniGamePacket, outgoing: Bool, sentAt: Date) throws -> ChatMessage {
            ChatMessage(
                id: UUID().uuidString,
                conversationID: conversationID,
                senderIdentityID: outgoing ? "host" : "guest",
                body: try MiniGameCodec.encode(packet),
                sentAt: sentAt,
                isOutgoing: outgoing,
                deliveryState: .delivered
            )
        }

        let canonical = try [
            message(invite, outgoing: true, sentAt: base),
            message(accept, outgoing: false, sentAt: base.addingTimeInterval(1)),
            message(moves[0], outgoing: true, sentAt: base.addingTimeInterval(2)),
            message(moves[1], outgoing: false, sentAt: base.addingTimeInterval(3)),
            message(moves[2], outgoing: true, sentAt: base.addingTimeInterval(4)),
            message(moves[3], outgoing: false, sentAt: base.addingTimeInterval(5))
        ]
        var noisy = canonical
        noisy.append(try message(moves[1], outgoing: false, sentAt: base.addingTimeInterval(30)))
        noisy.append(try message(moves[0], outgoing: true, sentAt: base.addingTimeInterval(40)))
        noisy = [noisy[5], noisy[2], noisy[7], noisy[0], noisy[4], noisy[1], noisy[6], noisy[3]]

        let expected = MiniGameSessionBuilder.session(id: invite.sessionID, from: canonical)
        let rebuilt = MiniGameSessionBuilder.session(id: invite.sessionID, from: noisy)
        XCTAssertEqual(rebuilt?.status, expected?.status)
        XCTAssertEqual(rebuilt?.moveCount, expected?.moveCount)
        XCTAssertEqual(rebuilt?.gomoku, expected?.gomoku)
        XCTAssertEqual(rebuilt?.lastActivity, expected?.lastActivity)
    }

    func testTacticalInitialStateHasHexMapAndLegalOrders() {
        let state = TacticalState()
        XCTAssertEqual(TacticalState.hexes.count, TacticalState.rows * TacticalState.columns)
        XCTAssertEqual(state.currentPlayer, .host)
        XCTAssertEqual(state.round, 1)
        XCTAssertEqual(state.ordersRemaining, TacticalState.ordersPerActivation)
        XCTAssertEqual(state.units(for: .host).count, 6)
        XCTAssertEqual(state.units(for: .guest).count, 6)
        XCTAssertTrue(state.legalDestinations(from: 55, actor: .host).contains(46))
        XCTAssertFalse(state.legalDestinations(from: 55, actor: .guest).contains(46))
        XCTAssertEqual(state.hex(at: 31)?.name, "官渡")
        XCTAssertEqual(state.hex(at: 10)?.name, "乌巢")
        XCTAssertEqual(state.hex(at: 22)?.name, "白马")
    }

    func testTacticalTwoOrdersThenSwitchesActivation() {
        var state = TacticalState()
        let sessionID = UUID().uuidString
        XCTAssertTrue(state.apply(from: 55, to: 46, actor: .host, sessionID: sessionID))
        XCTAssertEqual(state.currentPlayer, .host)
        XCTAssertEqual(state.ordersRemaining, 1)
        XCTAssertEqual(state.turn, 1)
        XCTAssertTrue(state.apply(from: nil, to: nil, actor: .host, sessionID: sessionID))
        XCTAssertEqual(state.currentPlayer, .guest)
        XCTAssertEqual(state.ordersRemaining, TacticalState.ordersPerActivation)
        XCTAssertEqual(state.turn, 2)
    }

    func testTacticalEncryptedHistoryRebuildsDeterministically() throws {
        let conversationID = UUID().uuidString
        let base = Date(timeIntervalSince1970: 4_000)
        let invite = MiniGamePacket(game: .tactical, command: .invite, createdAt: base)
        let accept = MiniGamePacket(sessionID: invite.sessionID, game: .tactical, command: .accept, createdAt: base.addingTimeInterval(1))
        let move = MiniGamePacket(sessionID: invite.sessionID, game: .tactical, command: .move, turn: 0, move: .tactical(from: 55, to: 46), createdAt: base.addingTimeInterval(2))
        let pass = MiniGamePacket(sessionID: invite.sessionID, game: .tactical, command: .move, turn: 1, move: .tacticalPass(), createdAt: base.addingTimeInterval(3))
        let messages = [
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(invite), sentAt: base, isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "guest", body: try MiniGameCodec.encode(accept), sentAt: base.addingTimeInterval(1), isOutgoing: false, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(move), sentAt: base.addingTimeInterval(2), isOutgoing: true, deliveryState: .delivered),
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: "host", body: try MiniGameCodec.encode(pass), sentAt: base.addingTimeInterval(3), isOutgoing: true, deliveryState: .delivered)
        ]
        let snapshot = MiniGameSessionBuilder.session(id: invite.sessionID, from: messages)
        XCTAssertEqual(snapshot?.game, .tactical)
        XCTAssertEqual(snapshot?.moveCount, 2)
        XCTAssertEqual(snapshot?.tactical?.unit(id: "cao-command")?.position, 46)
        XCTAssertEqual(snapshot?.tactical?.currentPlayer, .guest)
        XCTAssertEqual(snapshot?.lastActivity, base.addingTimeInterval(3))
    }

    func testTacticalDuplicatePacketDoesNotAdvanceTwice() throws {
        let conversationID = UUID().uuidString
        let base = Date(timeIntervalSince1970: 5_000)
        let invite = MiniGamePacket(game: .tactical, command: .invite, createdAt: base)
        let accept = MiniGamePacket(sessionID: invite.sessionID, game: .tactical, command: .accept, createdAt: base.addingTimeInterval(1))
        let move = MiniGamePacket(sessionID: invite.sessionID, game: .tactical, command: .move, turn: 0, move: .tactical(from: 55, to: 46), createdAt: base.addingTimeInterval(2))
        func message(_ packet: MiniGamePacket, outgoing: Bool, at time: TimeInterval) throws -> ChatMessage {
            ChatMessage(id: UUID().uuidString, conversationID: conversationID, senderIdentityID: outgoing ? "host" : "guest", body: try MiniGameCodec.encode(packet), sentAt: base.addingTimeInterval(time), isOutgoing: outgoing, deliveryState: .delivered)
        }
        let messages = try [
            message(invite, outgoing: true, at: 0),
            message(accept, outgoing: false, at: 1),
            message(move, outgoing: true, at: 2),
            message(move, outgoing: true, at: 80)
        ]
        let snapshot = MiniGameSessionBuilder.session(id: invite.sessionID, from: messages)
        XCTAssertEqual(snapshot?.moveCount, 1)
        XCTAssertEqual(snapshot?.tactical?.unit(id: "cao-command")?.position, 46)
        XCTAssertEqual(snapshot?.lastActivity, base.addingTimeInterval(2))
    }

    func testTacticalLocalRenderCacheIsCompleteAndDeterministic() {
        XCTAssertEqual(TacticalLocalRenderCache.cells.count, TacticalState.rows * TacticalState.columns)
        XCTAssertEqual(Set(TacticalLocalRenderCache.cells.map(\.index)).count, TacticalState.rows * TacticalState.columns)
        XCTAssertEqual(TacticalLocalRenderCache.hexVertices.count, 6)
        for terrain in [TacticalTerrain.plain, .road, .forest, .hill, .river, .ford, .camp] {
            XCTAssertFalse(TacticalLocalRenderCache.terrainSegments[terrain, default: []].isEmpty)
        }
        XCTAssertNotNil(TacticalLocalRenderCache.counterStyles[.cao])
        XCTAssertNotNil(TacticalLocalRenderCache.counterStyles[.yuan])
    }

}
