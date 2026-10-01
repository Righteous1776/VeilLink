import XCTest
@testable import VeilLink

final class CollaborativeStressProtocolTests: XCTestCase {
    func testFrameRoundTripAndPrefixIsolation() throws {
        let sessionID = UUID().uuidString
        let frame = CollaborativeStressFrame(
            sessionID: sessionID,
            epoch: 7,
            ordinal: 1,
            kind: .textBurst,
            payloadText: CollaborativeStressPayloadFactory.text(bytes: 1024, seed: 42)
        )
        let encoded = try CollaborativeStressCodec.encode(frame)
        XCTAssertTrue(encoded.hasPrefix(CollaborativeStressCodec.prefix))
        XCTAssertEqual(CollaborativeStressCodec.decode(encoded), frame)
        XCTAssertNil(CollaborativeStressCodec.decode("ordinary chat"))
    }

    func testBulkAccumulatorVerifiesDigestAndOrdering() throws {
        let data = CollaborativeStressPayloadFactory.binary(bytes: 70_000, seed: 99)
        let chunkCount = Int(ceil(Double(data.count) / Double(CollaborativeStressCodec.bulkChunkBytes)))
        let frame = CollaborativeStressFrame(
            sessionID: UUID().uuidString,
            epoch: 9,
            ordinal: 1,
            kind: .bulkBegin,
            payloadKind: .syntheticImage,
            transferID: UUID().uuidString,
            wireMessageID: UUID().uuidString,
            byteCount: data.count,
            chunkCount: chunkCount,
            sha256Hex: CollaborativeStressPayloadFactory.sha256Hex(data)
        )
        let accumulator = try CollaborativeStressInboundBulkAccumulator(frame: frame)
        var receipt: CollaborativeStressBulkReceipt?
        for index in 0..<chunkCount {
            let lower = index * CollaborativeStressCodec.bulkChunkBytes
            let upper = min(lower + CollaborativeStressCodec.bulkChunkBytes, data.count)
            receipt = try accumulator.accept(index: index, total: chunkCount, bytes: Data(data[lower..<upper]))
        }
        XCTAssertEqual(receipt?.success, true)
        XCTAssertEqual(receipt?.byteCount, data.count)
    }


    func testBulkReadyRequiresMatchingTransferIdentityFields() throws {
        let ready = CollaborativeStressFrame(
            sessionID: UUID().uuidString,
            epoch: 3,
            ordinal: 2,
            kind: .bulkReady,
            transferID: UUID().uuidString,
            wireMessageID: UUID().uuidString,
            success: true
        )
        let encoded = try CollaborativeStressCodec.encode(ready)
        XCTAssertEqual(CollaborativeStressCodec.decode(encoded), ready)

        let invalid = CollaborativeStressFrame(
            sessionID: UUID().uuidString,
            epoch: 3,
            ordinal: 3,
            kind: .bulkReady,
            transferID: nil,
            wireMessageID: UUID().uuidString
        )
        XCTAssertThrowsError(try CollaborativeStressCodec.encode(invalid))
    }

    func testScenarioNormalizationCapsObserverEffect() {
        var scenario = CollaborativeStressScenario()
        scenario.textBurstCount = 999_999
        scenario.textPayloadBytes = 99_999
        scenario.imagePayloadBytes = 99_999_999
        scenario.voicePayloadBytes = 99_999_999
        scenario.gameMoveCount = 99_999
        scenario.interFrameDelayMilliseconds = 0
        let value = scenario.normalized
        XCTAssertEqual(value.textBurstCount, 2_000)
        XCTAssertEqual(value.textPayloadBytes, CollaborativeStressScenario.maximumTextPayloadBytes)
        XCTAssertEqual(value.imagePayloadBytes, CollaborativeStressScenario.maximumBulkPayloadBytes)
        XCTAssertEqual(value.voicePayloadBytes, 512 * 1_024)
        XCTAssertEqual(value.gameMoveCount, 240)
        XCTAssertGreaterThanOrEqual(value.interFrameDelayMilliseconds, 8)
    }
}
