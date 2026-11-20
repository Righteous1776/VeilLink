import CryptoKit
import Foundation
import XCTest
@testable import VeilLink

/// V30 source tests: not proof of signing, real Bluetooth or ReplayKit transfer.
final class VeilScreenTransportIntegrationTests: XCTestCase {
    private func signedHello(screenSupported: Bool) throws -> HelloPacket {
        let key = Curve25519.Signing.PrivateKey()
        let agreement = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = key.publicKey.rawRepresentation
        let identityID = CryptoEngine.identityID(publicKey: publicKey)
        let unsigned = HelloPacket(
            protocolVersion: 4,
            identityID: identityID,
            displayName: "Test sender",
            identityPublicKey: publicKey,
            agreementPublicKey: agreement.publicKey.rawRepresentation,
            nonce: Data(repeating: 0x42, count: 16),
            signature: Data()
        )
        var signed = HelloPacket(
            protocolVersion: unsigned.protocolVersion,
            identityID: unsigned.identityID,
            displayName: unsigned.displayName,
            identityPublicKey: unsigned.identityPublicKey,
            agreementPublicKey: unsigned.agreementPublicKey,
            nonce: unsigned.nonce,
            signature: try key.signature(for: unsigned.signedPayload)
        )
        if screenSupported {
            signed.screenShareSchema = 1
            let transcript = try XCTUnwrap(signed.signedScreenSharePayload)
            signed.screenShareSignature = try key.signature(for: transcript)
        }
        return signed
    }

    func testSignedScreenShareCapabilityAndLegacyPeer() throws {
        let signed = try signedHello(screenSupported: true)
        XCTAssertTrue(signed.hasAuthenticatedScreenShareCapability())
        let legacy = try signedHello(screenSupported: false)
        XCTAssertFalse(legacy.hasAuthenticatedScreenShareCapability())
        XCTAssertEqual(legacy.protocolVersion, signed.protocolVersion)
    }

    func testManipulationFailsClosed() throws {
        let signed = try signedHello(screenSupported: true)
        var tampered = signed
        tampered.screenShareSchema = 2
        XCTAssertFalse(tampered.hasAuthenticatedScreenShareCapability())
        tampered = signed
        tampered.screenShareSignature = Data(repeating: 0, count: 64)
        XCTAssertFalse(tampered.hasAuthenticatedScreenShareCapability())
    }

    func testOptionalV4ScreenMetadataRoundTrips() throws {
        let original = try signedHello(screenSupported: true)
        let restored = try JSONDecoder().decode(
            HelloPacket.self, from: JSONEncoder().encode(original)
        )
        XCTAssertTrue(restored.hasAuthenticatedScreenShareCapability())
        let legacy = try signedHello(screenSupported: false)
        let legacyRestored = try JSONDecoder().decode(
            HelloPacket.self, from: JSONEncoder().encode(legacy)
        )
        XCTAssertNil(legacyRestored.screenShareSchema)
    }

    func testTypedScreenChannelsRemainDistinctFromChat() throws {
        let sessionID = UUID()
        let control = VeilScreenShareControl(sessionID: sessionID, action: .invite)
        XCTAssertEqual(try VeilScreenShareControl.decode(control.encode()), control)
        let fragment = try XCTUnwrap(VeilScreenShareChunk.split(
            image: Data(repeating: 0x24, count: 1_000),
            sessionID: sessionID, frameID: 7, width: 320, height: 640
        ).first)
        XCTAssertEqual(try VeilScreenShareChunk.decode(fragment.encode()), fragment)
        XCTAssertNotEqual(WireKind.screenControl.rawValue, WireKind.screenMedia.rawValue)
        XCTAssertNotEqual(WireKind.screenMedia.rawValue, WireKind.encryptedMessage.rawValue)
        XCTAssertNotEqual(WireKind.screenMedia.rawValue, WireKind.attachmentChunk.rawValue)
    }
}
