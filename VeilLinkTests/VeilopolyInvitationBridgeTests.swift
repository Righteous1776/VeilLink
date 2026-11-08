import Foundation
import XCTest
import VeilopolyNet
@testable import VeilLink

@MainActor
private final class InvitationChannel: VeilopolyControlChannel {
    var ready = true
    var result: TransportSendResult = .accepted
    var recoveries = 0
    var sent: [(VeilControlEvent, String)] = []
    var firstSend: (() -> Void)?
    func hasSecureSession(for peerIdentityID: String) -> Bool { ready }
    func recoverSecureSession(for peerIdentityID: String) -> Bool { recoveries += 1; return true }
    func sendControlEvent(_ event: VeilControlEvent, to peerIdentityID: String) -> TransportSendResult {
        sent.append((event, peerIdentityID))
        let callback = firstSend; firstSend = nil; callback?()
        return result
    }
}

/// Real host bridge with a fake authenticated channel. These tests do NOT
/// claim BLE/LAN/two-phone or rendered iPhone interaction acceptance.
@MainActor
final class VeilopolyInvitationBridgeTests: XCTestCase {
    private func conversation(_ peer: String = "guest") -> ConversationSummary {
        .init(id: "conversation-" + peer, title: peer, peerIdentityID: peer,
              lastMessage: "", updatedAt: Date(), unreadCount: 0, isPinned: false)
    }
    private func makeBridge(_ channel: InvitationChannel, local: String = "host") -> (VeilopolyMultiplayerBridge, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (.init(sessions: channel, localIdentity: { local },
                      resumeURL: directory.appendingPathComponent("room.json"), gameSaveDirectory: directory), directory)
    }
    func testChatInviteUsesSameBridgeAndCurrentRulesWithoutOpeningGameHall() async throws {
        let channel = InvitationChannel(); let (bridge, directory) = makeBridge(channel)
        defer { bridge.leaveRoom(); try? FileManager.default.removeItem(at: directory) }
        let sent = expectation(description: "encrypted control attempt")
        channel.firstSend = { sent.fulfill() }
        bridge.invite(conversation(), presentationContext: "chat-conversation-guest")
        XCTAssertEqual(bridge.outgoingInvitation?.effectiveRulesVersion, 5)
        XCTAssertEqual(bridge.activePeerIdentityID, "guest")
        XCTAssertEqual(bridge.presentationContext, "chat-conversation-guest")
        await fulfillment(of: [sent], timeout: 3)
        XCTAssertEqual(channel.sent.first?.1, "guest")
        XCTAssertEqual(channel.recoveries, 0, "Healthy chat security must not be reset")
        XCTAssertTrue(try channel.sent.allSatisfy { try VeilControlEventCodec.encode($0.0).count <= 2_048 })
    }
    func testOneExplicitInviteWaitsForRecoveryWithoutRequiringASecondTap() async {
        let channel = InvitationChannel(); channel.ready = false
        let (bridge, directory) = makeBridge(channel)
        defer { bridge.leaveRoom(); try? FileManager.default.removeItem(at: directory) }
        bridge.invite(conversation(), presentationContext: "chat")
        let roomID = bridge.outgoingInvitation?.roomID
        XCTAssertNotNil(roomID)
        XCTAssertTrue(channel.sent.isEmpty)
        XCTAssertEqual(channel.recoveries, 1)
        bridge.tick(); bridge.tick()
        XCTAssertEqual(channel.recoveries, 1, "A game timer cannot keep resetting chat security")
        let sent = expectation(description: "same invitation sent after readiness")
        channel.firstSend = { sent.fulfill() }
        channel.ready = true; bridge.tick()
        await fulfillment(of: [sent], timeout: 3)
        XCTAssertEqual(bridge.outgoingInvitation?.roomID, roomID)
        XCTAssertEqual(channel.recoveries, 1)
    }
    func testIncomingInviteAndAcceptanceWorkWithoutInstantiatingLobby() throws {
        let (bridge, directory) = makeBridge(InvitationChannel(), local: "guest")
        defer { bridge.leaveRoom(); try? FileManager.default.removeItem(at: directory) }
        let config = VeilopolyRoomConfiguration.current(roomID: UUID().uuidString, seed: 77,
            hostIdentityID: "host", guestIdentityID: "guest")
        let invite = VeilopolyRoomPacket(roomID: config.roomID, kind: .invite, configuration: config)
        for fragment in try VeilopolyControlCodec.fragments(invite) {
            bridge.receive(.init(topic: VeilopolyControlCodec.topic, payload: try JSONEncoder().encode(fragment)), from: "host")
        }
        XCTAssertEqual(bridge.incomingInvitation, config)
        XCTAssertFalse(bridge.isGamePresented, "Receiving is never automatic consent")
        bridge.acceptInvitation(presentationContext: "chat-guest")
        XCTAssertTrue(bridge.isGamePresented)
        XCTAssertEqual(bridge.presentationContext, "chat-guest")
        XCTAssertEqual(bridge.gameModel?.game.banking?.financeRuleVersion, 5)
        XCTAssertEqual(bridge.gameModel?.game.players.first?.cash, 25_000)
        bridge.presentGame(context: "game-lobby")
        XCTAssertEqual(bridge.presentationContext, "game-lobby", "Only the chosen route presents the shared room")
    }
    func testBusyRoomDoesNotSilentlyDropAnotherConversationInvite() {
        let channel = InvitationChannel(); channel.ready = false
        let (bridge, directory) = makeBridge(channel)
        defer { bridge.leaveRoom(); try? FileManager.default.removeItem(at: directory) }
        bridge.invite(conversation())
        let roomID = bridge.outgoingInvitation?.roomID
        bridge.invite(conversation("other"))
        XCTAssertEqual(bridge.outgoingInvitation?.roomID, roomID)
        XCTAssertEqual(bridge.activePeerIdentityID, "guest")
        XCTAssertEqual(bridge.lastActionPeer, "other")
        XCTAssertNotNil(bridge.lastError)
    }
    func testUnsupportedPeerShowsAnErrorInsteadOfAnInvitationSentClaim() async {
        let channel = InvitationChannel(); channel.result = .unsupportedLink
        let (bridge, directory) = makeBridge(channel)
        defer { bridge.leaveRoom(); try? FileManager.default.removeItem(at: directory) }
        let sent = expectation(description: "capability-rejected control attempt")
        channel.firstSend = { sent.fulfill() }
        bridge.invite(conversation(), presentationContext: "chat")
        await fulfillment(of: [sent], timeout: 3)
        XCTAssertNil(bridge.outgoingInvitation)
        XCTAssertTrue(bridge.lastError?.contains("未声明支持") == true)
        XCTAssertEqual(bridge.lastActionPeer, "guest")
    }
    func testInvitationCannotBeRelabelledAsADifferentAuthenticatedPeer() throws {
        let (bridge, directory) = makeBridge(InvitationChannel(), local: "guest")
        defer { bridge.leaveRoom(); try? FileManager.default.removeItem(at: directory) }
        let config = VeilopolyRoomConfiguration.current(roomID: UUID().uuidString, seed: 1,
            hostIdentityID: "host", guestIdentityID: "guest")
        for fragment in try VeilopolyControlCodec.fragments(.init(roomID: config.roomID,
            kind: .invite, configuration: config)) {
            bridge.receive(.init(topic: VeilopolyControlCodec.topic,
                payload: try JSONEncoder().encode(fragment)), from: "stranger")
        }
        XCTAssertNil(bridge.incomingInvitation)
        XCTAssertNil(bridge.gameModel)
    }
}
