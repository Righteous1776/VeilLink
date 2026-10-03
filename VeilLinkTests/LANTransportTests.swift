import XCTest
@testable import VeilLink

final class LANTransportTests: XCTestCase {
    func testFrameRoundTripAcrossFragmentedTCPReads() throws {
        let payload = Data((0..<10_000).map { UInt8($0 % 251) })
        let framed = try LANFrameCodec.encode(payload)
        var decoder = LANFrameDecoder()
        var decoded: [Data] = []

        for lower in stride(from: 0, to: framed.count, by: 137) {
            let upper = min(lower + 137, framed.count)
            decoded.append(contentsOf: try decoder.append(Data(framed[lower..<upper])))
        }

        XCTAssertEqual(decoded, [payload])
        XCTAssertEqual(decoder.bufferedByteCount, 0)
    }

    func testDecoderHandlesCoalescedFrames() throws {
        let first = Data("first".utf8)
        let second = Data(repeating: 0xA5, count: 4096)
        var wire = try LANFrameCodec.encode(first)
        wire.append(try LANFrameCodec.encode(second))
        var decoder = LANFrameDecoder()
        XCTAssertEqual(try decoder.append(wire), [first, second])
    }

    func testDecoderHandlesLargeCoalescedBatchAndRetainsOnlyPartialTail() throws {
        let payloads = (0..<2_048).map { index in
            Data(repeating: UInt8(index % 251), count: 32)
        }
        var wire = Data()
        for payload in payloads { wire.append(try LANFrameCodec.encode(payload)) }

        let trailingPayload = Data(repeating: 0x7E, count: 513)
        let trailingFrame = try LANFrameCodec.encode(trailingPayload)
        let split = trailingFrame.count / 2
        wire.append(trailingFrame.prefix(split))

        var decoder = LANFrameDecoder()
        XCTAssertEqual(try decoder.append(wire), payloads)
        XCTAssertEqual(decoder.bufferedByteCount, split)
        XCTAssertEqual(try decoder.append(Data(trailingFrame.dropFirst(split))), [trailingPayload])
        XCTAssertEqual(decoder.bufferedByteCount, 0)
    }

    func testHealthyRefreshPreservesInfrastructureWhileMissingPiecesAreRepaired() {
        XCTAssertEqual(
            LANInfrastructureRecoveryPolicy.refreshAction(
                isRunning: true,
                hasListener: true,
                hasBrowser: true
            ),
            .preserveHealthyInfrastructure
        )
        XCTAssertEqual(
            LANInfrastructureRecoveryPolicy.refreshAction(
                isRunning: true,
                hasListener: false,
                hasBrowser: true
            ),
            .repairMissingInfrastructure
        )
        XCTAssertEqual(
            LANInfrastructureRecoveryPolicy.refreshAction(
                isRunning: false,
                hasListener: false,
                hasBrowser: false
            ),
            .start
        )
    }

    func testInfrastructureRecoveryIsBounded() {
        let delays = (0..<LANInfrastructureRecoveryPolicy.maximumAttempts).compactMap {
            LANInfrastructureRecoveryPolicy.retryDelay(attempt: $0)
        }
        XCTAssertEqual(delays.count, LANInfrastructureRecoveryPolicy.maximumAttempts)
        XCTAssertNil(LANInfrastructureRecoveryPolicy.retryDelay(
            attempt: LANInfrastructureRecoveryPolicy.maximumAttempts
        ))
        XCTAssertNil(LANInfrastructureRecoveryPolicy.retryDelay(attempt: -1))
        for pair in zip(delays, delays.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0, pair.1)
        }
    }

    func testRejectsOversizedPayloadAndInvalidWireLength() throws {
        XCTAssertThrowsError(try LANFrameCodec.encode(Data(repeating: 1, count: LANFrameCodec.maximumPayloadBytes + 1)))

        var invalidLength = UInt32(LANFrameCodec.maximumPayloadBytes + 1).bigEndian
        let header = Data(bytes: &invalidLength, count: LANFrameCodec.headerBytes)
        var decoder = LANFrameDecoder()
        XCTAssertThrowsError(try decoder.append(header))
        XCTAssertEqual(decoder.bufferedByteCount, 0)
    }
}
