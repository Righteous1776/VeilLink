import Foundation

/// Session-local, lossy video scheduler. Video uses lower priority than chat and
/// control; a frame is never retried as if it were a durable chat attachment.
struct VeilScreenBLEScheduler {
    private struct Pending {
        let frameID: UInt64
        let chunks: [VeilScreenShareChunk]
        let enqueuedAt: TimeInterval
        var nextIndex: Int = 0
    }

    private var active: Pending?
    private var newestWaiting: Pending?
    private(set) var lastOfferedID: UInt64?
    private(set) var droppedFrames = 0
    private(set) var admittedChunks = 0

    private let maxQueuedBLEBytes = 8 * 1024
    private let maxFrameAge: TimeInterval = 7

    var hasPendingVideo: Bool { active != nil || newestWaiting != nil }

    /// Replaces the waiting frame, not a partially transmitted active frame.
    /// Bounds memory to at most two compressed frames / 64 KiB of payload.
    @discardableResult
    mutating func offer(image: Data, sessionID: UUID, frameID: UInt64,
                        width: Int, height: Int, now: TimeInterval) -> Bool {
        guard lastOfferedID.map({ frameID > $0 }) ?? true,
              let chunks = try? VeilScreenShareChunk.split(
                image: image, sessionID: sessionID, frameID: frameID, width: width, height: height
              ) else { return false }
        let next = Pending(frameID: frameID, chunks: chunks, enqueuedAt: now)
        lastOfferedID = frameID
        if active == nil { active = next }
        else {
            if newestWaiting != nil { droppedFrames += 1 }
            newestWaiting = next
        }
        return true
    }

    /// Peek does NOT consume. Call didAdmit() *only* after BLE queue accepted
    /// the exact packet; otherwise a full queue would silently lose chunks.
    mutating func peek(pendingBLEBytes: Int, now: TimeInterval) -> VeilScreenShareChunk? {
        expireOld(at: now)
        guard pendingBLEBytes >= 0, pendingBLEBytes < maxQueuedBLEBytes else { return nil }
        guard let item = active, item.nextIndex < item.chunks.count else { return nil }
        return item.chunks[item.nextIndex]
    }

    /// This acknowledgment means enqueued locally, NOT received by the peer.
    @discardableResult
    mutating func didAdmit(_ accepted: VeilScreenShareChunk) -> Bool {
        guard var item = active, item.nextIndex < item.chunks.count,
              item.frameID == accepted.frameID,
              item.chunks[item.nextIndex] == accepted else { return false }
        item.nextIndex += 1
        admittedChunks += 1
        if item.nextIndex == item.chunks.count {
            active = newestWaiting
            newestWaiting = nil
        } else { active = item }
        return true
    }

    /// On stop, consent revocation, identity change, or disconnect.
    mutating func cancel() {
        active = nil
        newestWaiting = nil
        lastOfferedID = nil
    }

    private mutating func expireOld(at now: TimeInterval) {
        if let item = active, now - item.enqueuedAt > maxFrameAge {
            droppedFrames += 1
            active = newestWaiting
            newestWaiting = nil
        }
        if let item = newestWaiting, now - item.enqueuedAt > maxFrameAge {
            droppedFrames += 1
            newestWaiting = nil
        }
    }
}
