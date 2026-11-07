import CryptoKit
import Foundation
import XCTest
@testable import VeilLink

final class VeilHelloCapabilityTests: XCTestCase {
    private struct LegacyHello: Codable {
        let protocolVersion: Int
        let identityID: String
        let displayName: String
        let identityPublicKey: Data
        let agreementPublicKey: Data
        let nonce: Data
        let signature: Data

        var signedPayload: Data {
            var bytes = Data("VeilLink/Hello/v4|\(protocolVersion)|\(identityID)|\(displayName)|".utf8)
            bytes.append(identityPublicKey)
            bytes.append(agreementPublicKey)
            bytes.append(nonce)
            return bytes
        }
    }

    private func helloWithKey() throws -> (HelloPacket, Curve25519.Signing.PrivateKey) {
        let key = Curve25519.Signing.PrivateKey()
        let pub = key.publicKey.rawRepresentation
        let ephemeral = Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
        let id = CryptoEngine.identityID(publicKey: pub)
        let unsigned = HelloPacket(
            protocolVersion: 4, identityID: id, displayName: "test peer",
            identityPublicKey: pub, agreementPublicKey: ephemeral,
            nonce: Data(repeating: 0x4D, count: 16), signature: Data()
        )
        let signature = try key.signature(for: unsigned.signedPayload)
        return (
            HelloPacket(protocolVersion: 4, identityID: id, displayName: "test peer",
                        identityPublicKey: pub, agreementPublicKey: ephemeral,
                        nonce: Data(repeating: 0x4D, count: 16), signature: signature),
            key
        )
    }

    func testLegacyHelloDecoderAcceptsSignedR5Metadata() throws {
        var (hello, key) = try helloWithKey()
        let oldSignedPayload = hello.signedPayload
        hello.capabilitySchema = 1
        hello.capabilityBits = 7
        hello.capabilitySignature = try key.signature(for: XCTUnwrap(hello.signedCapabilitiesPayload))
        let encoded = try JSONEncoder().encode(hello)

        let legacy = try JSONDecoder().decode(LegacyHello.self, from: encoded)
        XCTAssertEqual(legacy.signedPayload, oldSignedPayload)
        try CryptoEngine.verify(signature: legacy.signature, for: legacy.signedPayload, publicKey: legacy.identityPublicKey)
        let upgraded = try JSONDecoder().decode(HelloPacket.self, from: encoded)
        XCTAssertEqual(upgraded.verifiedCapabilityBits(), 7)
    }

    func testLegacyWireV4HelloCanStillBeDecodedByR5() throws {
        let (hello, _) = try helloWithKey()
        let legacy = LegacyHello(
            protocolVersion: hello.protocolVersion, identityID: hello.identityID,
            displayName: hello.displayName, identityPublicKey: hello.identityPublicKey,
            agreementPublicKey: hello.agreementPublicKey, nonce: hello.nonce, signature: hello.signature
        )
        let upgraded = try JSONDecoder().decode(HelloPacket.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(upgraded.verifiedCapabilityBits())
        XCTAssertNil(upgraded.capabilitySignature)
        XCTAssertEqual(upgraded.signedPayload, legacy.signedPayload)
    }

    func testCapabilityTamperingOnlyDisablesOptionalFeatures() throws {
        var (hello, key) = try helloWithKey()
        hello.capabilitySchema = 1
        hello.capabilityBits = 7
        hello.capabilitySignature = try key.signature(for: XCTUnwrap(hello.signedCapabilitiesPayload))
        XCTAssertEqual(hello.verifiedCapabilityBits(), 7)
        hello.capabilityBits = 3
        XCTAssertNil(hello.verifiedCapabilityBits())
        try CryptoEngine.verify(signature: hello.signature, for: hello.signedPayload, publicKey: hello.identityPublicKey)
    }

    func testTamperedSessionEphemeralCannotReuseExtensionProof() throws {
        var (hello, key) = try helloWithKey()
        hello.capabilitySchema = 1
        hello.capabilityBits = 7
        hello.capabilitySignature = try key.signature(for: XCTUnwrap(hello.signedCapabilitiesPayload))
        let original = hello.capabilitySignature
        hello = HelloPacket(
            protocolVersion: hello.protocolVersion,
            identityID: hello.identityID,
            displayName: hello.displayName,
            identityPublicKey: hello.identityPublicKey,
            agreementPublicKey: Data(repeating: 0x19, count: 32),
            nonce: hello.nonce,
            signature: hello.signature,
            capabilitySchema: hello.capabilitySchema,
            capabilityBits: hello.capabilityBits,
            capabilitySignature: hello.capabilitySignature
        )
        // This would fail the original v4 Hello signature too; the R5 supplement
        // is additionally cryptographically bound to the exact same v4 transcript.
        XCTAssertEqual(hello.capabilitySignature, original)
        XCTAssertNil(hello.verifiedCapabilityBits())
    }

    func testInvalidOrUnknownExtensionDoesNotGrantCapabilities() throws {
        var (hello, key) = try helloWithKey()
        hello.capabilitySchema = 1
        hello.capabilityBits = 8
        hello.capabilitySignature = try key.signature(for: XCTUnwrap(hello.signedCapabilitiesPayload))
        XCTAssertNil(hello.verifiedCapabilityBits())
        hello.capabilitySchema = 2
        XCTAssertNil(hello.verifiedCapabilityBits())
        hello.capabilitySignature = nil
        XCTAssertNil(hello.verifiedCapabilityBits())
    }
}
