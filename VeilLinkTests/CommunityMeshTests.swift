import CryptoKit
import XCTest
@testable import VeilLink

final class CommunityMeshTests: XCTestCase {
    func testMeshPacketRoundTripAndRelay() throws {
        let payload = Data("hello mesh".utf8)
        let packet = try VeilMeshPacket(kind: .roomMessage, scope: .roomBroadcast, roomID: UUID(), hopLimit: 4, sealedPayload: payload)
        let decoded = try VeilMeshCodec.decode(VeilMeshCodec.encode(packet))
        XCTAssertEqual(decoded, packet)
        let relayed = try decoded.relayed()
        XCTAssertEqual(relayed.packetID, packet.packetID)
        XCTAssertEqual(relayed.hopCount, 1)
        XCTAssertEqual(relayed.sealedPayload, payload)
    }

    func testMeshHopLimitStopsRelay() throws {
        let packet = try VeilMeshPacket(kind: .presence, scope: .roomBroadcast, roomID: UUID(), hopLimit: 1, hopCount: 1, sealedPayload: Data([1]))
        XCTAssertFalse(packet.canRelay)
        XCTAssertThrowsError(try packet.relayed())
    }

    func testIdentifiedCommunityMessageVerifiesIdentity() throws {
        let authority = Curve25519.Signing.PrivateKey()
        let sender = Curve25519.Signing.PrivateKey()
        let identityID = CryptoEngine.identityID(publicKey: sender.publicKey.rawRepresentation)
        let room = VeilCommunityRoom(
            id: UUID(), title: "G", kind: .privateGroup, createdAt: Date(), ownerIdentityID: identityID,
            authorityPublicKey: authority.publicKey.rawRepresentation, epoch: 1, defaultHopLimit: 5, isDiscoverable: false
        )
        let key = VeilCommunityCrypto.generateRoomKey()
        let sealed = try VeilCommunityCrypto.seal(body: "hello", room: room, roomKey: key, senderMode: .identified, realIdentityID: identityID, signingKey: sender)
        let clear = try VeilCommunityCrypto.open(sealed, room: room, roomKey: key)
        XCTAssertEqual(clear.senderIdentityID, identityID)
        XCTAssertEqual(clear.body, "hello")
    }

    func testAnonymousCommunityMessageCarriesNoRealIdentity() throws {
        let authority = Curve25519.Signing.PrivateKey()
        let sender = VeilCommunityCrypto.anonymousSigningKey()
        let room = VeilCommunityRoom(
            id: UUID(), title: "Public", kind: .publicChannel, createdAt: Date(), ownerIdentityID: nil,
            authorityPublicKey: authority.publicKey.rawRepresentation, epoch: 1, defaultHopLimit: 8, isDiscoverable: true
        )
        let key = VeilCommunityCrypto.generateRoomKey()
        let sealed = try VeilCommunityCrypto.seal(body: "anonymous", room: room, roomKey: key, senderMode: .anonymous, realIdentityID: "SHOULD-NOT-LEAK", signingKey: sender)
        let clear = try VeilCommunityCrypto.open(sealed, room: room, roomKey: key)
        XCTAssertNil(clear.senderIdentityID)
        XCTAssertTrue(clear.senderAlias.hasPrefix("ANON-"))
    }
}
