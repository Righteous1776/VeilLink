import XCTest
@testable import VeilLink

final class VeilScreenShareWireTests: XCTestCase {
    func testAllControlCommandsRoundTrip() throws {
        let id = UUID()
        for command in [VeilScreenShareAction.invite, .accept, .decline, .ready, .stop] {
            let item = VeilScreenShareControl(sessionID: id, action: command)
            XCTAssertEqual(try VeilScreenShareControl.decode(item.encode()), item)
        }
    }

    func testOutOfOrderFrameReassemblyAndReplayRejection() throws {
        let id = UUID()
        let jpeg = Data((0..<12_345).map { UInt8(truncatingIfNeeded: $0) })
        let chunks = try VeilScreenShareChunk.split(image: jpeg, sessionID: id,
                                                     frameID: 99, width: 320, height: 640)
        var assembler = VeilScreenShareAssembler(sessionID: id)
        var output: VeilScreenShareFrame?
        for packet in chunks.reversed() {
            let reconstructed = try VeilScreenShareChunk.decode(packet.encode())
            if let frame = try assembler.receive(reconstructed, at: 100) { output = frame }
        }
        XCTAssertEqual(output?.image, jpeg)
        XCTAssertEqual(output?.frameID, 99)
        XCTAssertNil(try assembler.receive(chunks[0], at: 101))
    }

    func testRejectsOversizedAndCrossSessionPackets() throws {
        XCTAssertThrowsError(try VeilScreenShareChunk.split(image: Data(repeating: 1, count: 32_769),
                                                            sessionID: UUID(), frameID: 0,
                                                            width: 300, height: 400))
        let chunks = try VeilScreenShareChunk.split(image: Data(repeating: 1, count: 1000),
                                                     sessionID: UUID(), frameID: 1,
                                                     width: 300, height: 400)
        var different = VeilScreenShareAssembler(sessionID: UUID())
        XCTAssertThrowsError(try different.receive(chunks[0], at: 1))
    }

    func testAdaptiveBudgetPrioritizesChat() {
        var rate = VeilScreenShareRateController()
        rate.update(bytesPerSecond: 1_000, pendingBytes: 16_000)
        XCTAssertEqual(rate.targetWidth, 240)
        XCTAssertEqual(rate.interval, 5)
        rate.update(bytesPerSecond: 50_000, pendingBytes: 0)
        XCTAssertEqual(rate.targetWidth, 540)
        XCTAssertEqual(rate.interval, 0.5)
    }
}
