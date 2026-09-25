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

    func testRejectsOversizedPayloadAndInvalidWireLength() throws {
        XCTAssertThrowsError(try LANFrameCodec.encode(Data(repeating: 1, count: LANFrameCodec.maximumPayloadBytes + 1)))

        var invalidLength = UInt32(LANFrameCodec.maximumPayloadBytes + 1).bigEndian
        let header = Data(bytes: &invalidLength, count: LANFrameCodec.headerBytes)
        var decoder = LANFrameDecoder()
        XCTAssertThrowsError(try decoder.append(header))
        XCTAssertEqual(decoder.bufferedByteCount, 0)
    }
}
