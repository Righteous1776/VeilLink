import CryptoKit
import XCTest
@testable import VeilLink

final class VoiceAndPTTTests: XCTestCase {
    func testVoiceMetadataRoundTrip() {
        let body = VoiceMessageCodec.encode(durationSeconds: 3.42)
        let decoded = VoiceMessageCodec.decode(body)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.durationMilliseconds, 3420)
        XCTAssertEqual(VoiceMessageCodec.preview(durationSeconds: 3.42), "[语音] 3″")
    }

    func testVoiceMimeGate() {
        XCTAssertTrue(VoiceMessageCodec.isVoiceMIMEType("audio/mp4"))
        XCTAssertFalse(VoiceMessageCodec.isVoiceMIMEType("image/jpeg"))
    }

    func testPTTAudioCodecRoundTrip() throws {
        let talkID = UUID().uuidString
        let frame = VeilPTTAudioFrame(talkID: talkID, index: 7, muLawBytes: Data([1,2,3,4,5]))
        XCTAssertEqual(try VeilPTTCodec.decodeAudio(VeilPTTCodec.encodeAudio(frame)), frame)
    }

    func testPTTDefaultControlUsesLowLatencyFortyMillisecondFrames() throws {
        let packet = VeilPTTControlPacket(talkID: UUID().uuidString, kind: .begin)
        XCTAssertEqual(packet.sampleRate, 8_000)
        XCTAssertEqual(packet.frameDurationMilliseconds, 40)
        XCTAssertNoThrow(try VeilPTTCodec.encodeControl(packet))
    }

    func testFortyMillisecondPTTFrameFitsSingleObserved512ByteATTFragment() throws {
        let talkID = UUID().uuidString
        let clear = try VeilPTTCodec.encodeAudio(
            VeilPTTAudioFrame(talkID: talkID, index: 1, muLawBytes: Data(repeating: 0x7F, count: 320))
        )
        let encrypted = try CryptoEngine.encrypt(
            clear,
            key: SymmetricKey(size: .bits256),
            messageID: talkID,
            sequence: 1,
            context: "ptt-audio"
        )
        let envelope = try WireCodec.encodeEnvelope(
            version: 4,
            kind: .pttAudio,
            payload: try WireCodec.encodeEncryptedPayload(encrypted)
        )
        let plan = BLEFragment.fragmentationPlan(payloadByteCount: envelope.count, maximumPacketSize: 512)
        XCTAssertEqual(plan?.fragmentCount, 1)
        XCTAssertLessThanOrEqual(plan?.encodedByteCount ?? .max, 512)
    }

    func testMuLawKeepsSpeechSignAndBoundedError() {
        for value: Int16 in [-24000, -8000, -1200, 0, 1200, 8000, 24000] {
            let decoded = VeilMuLaw.decode(VeilMuLaw.encode(value))
            if value != 0 { XCTAssertEqual(decoded < 0, value < 0) }
            XCTAssertLessThan(abs(Int(decoded) - Int(value)), 5000)
        }
    }
}
