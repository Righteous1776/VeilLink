import XCTest
@testable import VeilLink

final class VeilScreenR1Tests: XCTestCase {
    func testIncomingInviteRequiresExplicitAccept() {
        let id = UUID()
        var session = VeilScreenSnapshot.incoming(peerID: "alice", at: 100, id: id)
        XCTAssertFalse(session.transition(.senderReady, at: 101))
        XCTAssertEqual(session.phase, .incomingInvite)
        XCTAssertTrue(session.transition(.localAccepted, at: 102))
        XCTAssertEqual(session.phase, .awaitingSender)
        XCTAssertFalse(session.transition(.firstFrame(id: 1), at: 103))
        XCTAssertTrue(session.transition(.senderReady, at: 104))
        XCTAssertTrue(session.transition(.firstFrame(id: 1), at: 105))
        XCTAssertEqual(session.phase, .live)
    }

    func testCaptureCannotStartBeforePickerAndViewerAck() {
        var session = VeilScreenSnapshot.outgoing(peerID: "bob", at: 100)
        XCTAssertFalse(session.transition(.captureStarted, at: 100))
        XCTAssertTrue(session.transition(.peerAccepted, at: 101))
        XCTAssertFalse(session.transition(.viewerReady, at: 102))
        XCTAssertTrue(session.transition(.systemPickerOpened, at: 102))
        XCTAssertFalse(session.transition(.viewerReady, at: 103))
        XCTAssertTrue(session.transition(.captureStarted, at: 104))
        XCTAssertEqual(session.phase, .connecting)
        XCTAssertTrue(session.transition(.viewerReady, at: 105))
        XCTAssertEqual(session.phase, .live)
    }

    func testStopClearsFrameAndRejectsLateCallback() {
        var session = VeilScreenSnapshot.incoming(peerID: "alice", at: 100, id: UUID())
        XCTAssertTrue(session.transition(.localAccepted, at: 101))
        XCTAssertTrue(session.transition(.senderReady, at: 102))
        XCTAssertTrue(session.transition(.firstFrame(id: 5), at: 103))
        XCTAssertTrue(session.transition(.peerStopped, at: 104))
        XCTAssertNil(session.lastFrameID)
        XCTAssertFalse(session.transition(.frame(id: 6), at: 105))
    }

    func testChunkV2ReverseOrderAndReplay() throws {
        let id = UUID()
        let bytes = Data(repeating: 0x5A, count: 10_001)
        let fragments = try VeilScreenShareChunk.split(image: bytes, sessionID: id,
                                                        frameID: UInt64.max - 1,
                                                        width: 320, height: 640)
        var assembler = VeilScreenShareAssembler(sessionID: id)
        var decoded: VeilScreenShareFrame?
        for fragment in fragments.reversed() {
            let chunk = try VeilScreenShareChunk.decode(fragment.encode())
            if let result = try assembler.receive(chunk, at: 100) { decoded = result }
        }
        XCTAssertEqual(decoded?.image, bytes)
        XCTAssertEqual(decoded?.frameID, UInt64.max - 1)
        XCTAssertNil(try assembler.receive(fragments[0], at: 101))
    }

    func testSenderDoesNotLosePacketWhenBLEQueueIsFull() throws {
        var sender = VeilScreenBLEScheduler()
        let id = UUID()
        XCTAssertTrue(sender.offer(image: Data(repeating: 1, count: 4_000),
                                   sessionID: id, frameID: 1,
                                   width: 320, height: 640, now: 100))
        XCTAssertNil(sender.peek(pendingBLEBytes: 9_000, now: 101))
        let packet = try XCTUnwrap(sender.peek(pendingBLEBytes: 0, now: 101))
        XCTAssertEqual(sender.peek(pendingBLEBytes: 0, now: 101), packet)
        XCTAssertTrue(sender.didAdmit(packet))
        XCTAssertFalse(sender.didAdmit(packet))
    }

    func testExpiredInviteAndForgedSessionID() {
        let id = UUID()
        var registry = VeilScreenSessionRegistry()
        XCTAssertTrue(registry.install(.incoming(peerID: "alice", at: 100, id: id),
                                       trustedPeerID: "alice", now: 101))
        XCTAssertFalse(registry.apply(.localAccepted, sessionID: UUID(), peerID: "alice", at: 102))
        XCTAssertFalse(registry.apply(.localAccepted, sessionID: id, peerID: "mallory", at: 102))
        XCTAssertFalse(registry.apply(.localAccepted, sessionID: id, peerID: "alice", at: 160))
        XCTAssertEqual(registry.active?.endReason, .expired)
    }
}
