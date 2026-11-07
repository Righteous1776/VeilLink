import Foundation
import XCTest
@testable import VeilLink

final class VeilControlEventCodecTests: XCTestCase {
    func testControlEventReceiptFlagIsBackwardOptional() throws {
        let event = VeilControlEvent(topic: "sync.cursor", payload: Data([0x01]))
        let encoded = try VeilControlEventCodec.encode(event)
        XCTAssertEqual(try VeilControlEventCodec.decode(encoded).receiptRequested, true)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "receiptRequested")
        let old = try JSONSerialization.data(withJSONObject: json)
        let restored = try VeilControlEventCodec.decode(old)
        XCTAssertNil(restored.receiptRequested)
        XCTAssertEqual(restored.eventID, event.eventID)
    }

    func testControlReceiptWireKindRoundTrip() throws {
        let payload = Data([1, 2, 3])
        let envelope = try WireCodec.encodeEnvelope(version: 4, kind: .controlReceipt, payload: payload)
        let decoded = try WireCodec.decodeEnvelope(envelope)
        XCTAssertEqual(decoded.kind, .controlReceipt)
        XCTAssertEqual(decoded.version, 4)
        XCTAssertEqual(decoded.payload, payload)
    }

    func testEnvelopeAndEventRoundTrip() throws {
        let event = VeilControlEvent(topic: "sync.cursor", payload: Data([1, 2, 3]))
        let raw = try VeilControlEventCodec.encode(event)
        let packet = try WireCodec.encodeEnvelope(version: 4, kind: .controlEvent, payload: raw)
        let decoded = try WireCodec.decodeEnvelope(packet)
        XCTAssertEqual(decoded.version, 4)
        XCTAssertEqual(decoded.kind, .controlEvent)
        XCTAssertEqual(try VeilControlEventCodec.decode(decoded.payload), event)
    }
    func testRejectOversizedAndUnknownEvent() throws {
        let tooLarge = VeilControlEvent(topic: "sync.cursor", payload: Data(repeating: 0x45, count: 24_577))
        XCTAssertThrowsError(try VeilControlEventCodec.encode(tooLarge))
        let valid = try VeilControlEventCodec.encode(VeilControlEvent(topic: "game.move", payload: Data()))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        json["schemaVersion"] = 2
        XCTAssertThrowsError(try VeilControlEventCodec.decode(try JSONSerialization.data(withJSONObject: json)))
        json["schemaVersion"] = 1
        json["topic"] = "Unsafe/Topic"
        XCTAssertThrowsError(try VeilControlEventCodec.decode(try JSONSerialization.data(withJSONObject: json)))
    }
}
