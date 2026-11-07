import Foundation
import XCTest
@testable import VeilLink

final class VeilPeerCapabilityPolicyTests: XCTestCase {
    private struct LegacyAcknowledgement: Codable { let messageID: String }

    func testExtendedAcknowledgementIsReadableByLegacyDecoder() throws {
        let current = WireAcknowledgement(messageID: "fixed-id", capabilitySchema: 1, capabilityBits: 1)
        let encoded = try JSONEncoder().encode(current)
        XCTAssertEqual(try JSONDecoder().decode(LegacyAcknowledgement.self, from: encoded).messageID, "fixed-id")
        let restored = try JSONDecoder().decode(WireAcknowledgement.self, from: encoded)
        XCTAssertEqual(restored.capabilitySchema, 1)
        XCTAssertEqual(restored.capabilityBits, 1)
    }

    func testLegacyAcknowledgementStillDecodes() throws {
        let old = try JSONEncoder().encode(LegacyAcknowledgement(messageID: "old-id"))
        let decoded = try JSONDecoder().decode(WireAcknowledgement.self, from: old)
        XCTAssertEqual(decoded.messageID, "old-id")
        XCTAssertNil(decoded.capabilitySchema)
        XCTAssertNil(decoded.capabilityBits)
    }

    func testMalformedOptionalDataCannotInvalidateRealACK() throws {
        let raw = Data(#"{"messageID":"valid-id","capabilitySchema":"bad","capabilityBits":-1}"#.utf8)
        let decoded = try JSONDecoder().decode(WireAcknowledgement.self, from: raw)
        XCTAssertEqual(decoded.messageID, "valid-id")
        XCTAssertNil(decoded.capabilitySchema)
        XCTAssertNil(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: decoded.capabilitySchema, bits: decoded.capabilityBits))
    }

    func testAckCapabilityDowngradePreservesR2Compatibility() {
        XCTAssertEqual(VeilPeerCapabilityPolicy.compatibleAckBits(forPeerBits: nil), 3)
        XCTAssertEqual(VeilPeerCapabilityPolicy.compatibleAckBits(forPeerBits: 0), 3)
        XCTAssertEqual(VeilPeerCapabilityPolicy.compatibleAckBits(forPeerBits: 1), 3)
        XCTAssertEqual(VeilPeerCapabilityPolicy.compatibleAckBits(forPeerBits: 3), 3)
        XCTAssertEqual(VeilPeerCapabilityPolicy.compatibleAckBits(forPeerBits: 7), 7)
        XCTAssertEqual(VeilPeerCapabilityPolicy.compatibleAckBits(forPeerBits: 4), 7)
    }

    func testUnknownCapabilitiesAreRejected() {
        XCTAssertEqual(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: 1, bits: 1), 1)
        XCTAssertNil(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: nil, bits: 1))
        XCTAssertNil(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: 2, bits: 1))
        XCTAssertNil(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: 1, bits: -1))
        XCTAssertEqual(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: 1, bits: 2), 2)
        XCTAssertEqual(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: 1, bits: 4), 4)
        XCTAssertEqual(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: 1, bits: 7), 7)
        XCTAssertNil(VeilPeerCapabilityPolicy.validatedBits(schemaVersion: 1, bits: 8))
    }
}
