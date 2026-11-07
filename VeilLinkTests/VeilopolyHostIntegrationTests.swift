import XCTest
import VeilopolyUI
import VeilopolyNet
import VeilopolyEngine
@testable import VeilLink

/// Runs inside the real VeilLink test host, unlike portable package-only tests.
final class VeilopolyHostIntegrationTests: XCTestCase {
    func testOfflineModuleResourcesTravelWithTheHostApp() {
        XCTAssertEqual(VeilopolyBundledContent.imageAliases.count, 99)
        XCTAssertEqual(VeilopolyBundledContent.sounds.count, 13)
        XCTAssertEqual(VeilopolyBundledContent.missingResources, [])
        XCTAssertEqual(VeilopolyBundledContent.invalidImages, [])
    }

    func testMultiplayerInviteUsesLinkedGameWireCodec() throws {
        let roomID = UUID().uuidString
        let invite = GameInvite(gameId: roomID, seed: 7003, humanSeats: [0, 1])
        let envelope = GameEnvelope(gameId: roomID, kind: .invite, invite: invite)
        let body = try VeilopolyRoomWire.encode(envelope)
        XCTAssertLessThan(body.utf8.count, VeilopolyRoomWire.maximumTextBytes)
        XCTAssertEqual(VeilopolyRoomWire.decode(body), envelope)
        XCTAssertEqual(VeilopolyRoomWire.previewText(for: body),
                       "[Veilopoly] 好友邀请你加入大富翁")
    }

    func testMultiplayerGuestCannotIssueHostOpeningMove() {
        let game = GameFactory.make(seed: 7003, humanCount: 2)
        var host = AuthoritativeHost(game: game)
        let hostile = Move(.rollDice, player: 1, seq: 0)
        guard case .failure = host.accept(hostile) else {
            return XCTFail("Remote guest must not control host seat")
        }
        XCTAssertEqual(host.game, game)
    }

    func testConfirmedTextIsAvailableFromTheLinkedGameModule() {
        let text = VeilopolyBundledContent.compiledTextCounts
        XCTAssertEqual(text["cards"], 32)
        XCTAssertEqual(text["streets"], 40)
        XCTAssertEqual(text["issuers"], 5)
        XCTAssertEqual(text["guide"], 23)
        XCTAssertEqual(text["news"], 86)
    }
}
