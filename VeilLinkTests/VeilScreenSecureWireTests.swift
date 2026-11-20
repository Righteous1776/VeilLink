import Foundation
import CryptoKit
import XCTest
@testable import VeilLink

final class VeilScreenSecureWireTests: XCTestCase {
    private struct LegacyHello: Codable {
        let protocolVersion: Int
        let identityID: String
        let displayName: String
        let identityPublicKey: Data
        let agreementPublicKey: Data
        let nonce: Data
        let signature: Data
    }

    func testNewScreenEnvelopeKindsAreDistinctFromExistingV4() throws {
        XCTAssertEqual(WireKind.screenControl.rawValue, 12)
        XCTAssertEqual(WireKind.screenMedia.rawValue, 13)
        let message = VeilScreenShareControl(sessionID: UUID(), action: .invite)
        let encoded = try WireCodec.encodeEnvelope(
            version: 4, kind: .screenControl, payload: message.encode()
        )
        let decoded = try WireCodec.decodeEnvelope(encoded)
        XCTAssertEqual(decoded.kind, .screenControl)
        XCTAssertEqual(try VeilScreenShareControl.decode(decoded.payload), message)
    }

    func testSignedScreenCapabilityAndLegacyCompatibility() throws {
        let key = Curve25519.Signing.PrivateKey()
        let id = CryptoEngine.identityID(publicKey: key.publicKey.rawRepresentation)
        let nonce = Data(repeating: 7, count: 16)
        let unsigned = HelloPacket(protocolVersion: 4, identityID: id,
            displayName: "Test", identityPublicKey: key.publicKey.rawRepresentation,
            agreementPublicKey: Data(repeating: 4, count: 32),
            nonce: nonce, signature: Data())
        var hello = HelloPacket(protocolVersion: 4, identityID: id,
            displayName: "Test", identityPublicKey: key.publicKey.rawRepresentation,
            agreementPublicKey: Data(repeating: 4, count: 32),
            nonce: nonce, signature: try key.signature(for: unsigned.signedPayload))
        XCTAssertFalse(hello.verifiedScreenShareCapability())
        hello.screenShareSchema = 1
        hello.screenShareSignature = try key.signature(for: XCTUnwrap(hello.signedScreenSharePayload))
        XCTAssertTrue(hello.verifiedScreenShareCapability())
        let bytes = try JSONEncoder().encode(hello)
        let legacy = try JSONDecoder().decode(LegacyHello.self, from: bytes)
        XCTAssertEqual(legacy.signature, hello.signature)
        var tampered = hello
        tampered.screenShareSignature = Data(repeating: 0, count: 64)
        XCTAssertFalse(tampered.verifiedScreenShareCapability())
    }

    func testChunkSessionIsolationAndReplay() throws {
        let session = UUID()
        let chunks = try VeilScreenShareChunk.split(
            image: Data(repeating: 0xAB, count: 1000),
            sessionID: session, frameID: 7, width: 240, height: 240
        )
        XCTAssertEqual(chunks.count, 3)
        var assembler = VeilScreenShareAssembler(sessionID: session)
        XCTAssertNil(try assembler.receive(chunks[2], at: 1))
        XCTAssertNil(try assembler.receive(chunks[0], at: 1))
        let frame = try XCTUnwrap(assembler.receive(chunks[1], at: 1))
        XCTAssertEqual(frame.image.count, 1000)
        XCTAssertNil(try assembler.receive(chunks[1], at: 2))
        var wrong = VeilScreenShareAssembler(sessionID: UUID())
        XCTAssertThrowsError(try wrong.receive(chunks[0], at: 1))
    }
}
