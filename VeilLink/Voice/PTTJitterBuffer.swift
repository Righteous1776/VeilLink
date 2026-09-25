import Foundation

enum VeilPTTPlayoutItem: Equatable {
    case frame(Data)
    case conceal(frameBytes: Int)
    case wait
    case finished
}

struct VeilPTTJitterSnapshot: Equatable, Sendable {
    let queuedFrames: Int
    let targetDepth: Int
    let lateFrames: Int
    let duplicateFrames: Int
    let reorderedFrames: Int
    let concealedFrames: Int
    let overflowDrops: Int

    var lossLikeEvents: Int { lateFrames + duplicateFrames + concealedFrames + overflowDrops }
}

struct VeilRealtimeAudioTuning: Equatable, Sendable {
    let targetJitterFrames: Int
    let maximumJitterFrames: Int
    let missingFramePatienceTicks: Int
    let preferredIOBufferDuration: Double
    let captureBufferFrames: UInt32
    let meterPublishInterval: Double
    let playbackProgressInterval: Double

    static func resolved(performanceLabel: String) -> VeilRealtimeAudioTuning {
        let label = performanceLabel.uppercased()
        let legacy = label.contains("LEGACY") || label.contains("SE1")
        if legacy {
            return VeilRealtimeAudioTuning(
                targetJitterFrames: 2,
                maximumJitterFrames: 6,
                missingFramePatienceTicks: 1,
                preferredIOBufferDuration: 0.02,
                captureBufferFrames: 960,
                meterPublishInterval: 0.12,
                playbackProgressInterval: 0.12
            )
        }
        return VeilRealtimeAudioTuning(
            targetJitterFrames: 1,
            maximumJitterFrames: 6,
            missingFramePatienceTicks: 1,
            preferredIOBufferDuration: 0.012,
            captureBufferFrames: 480,
            meterPublishInterval: 0.08,
            playbackProgressInterval: 0.08
        )
    }
}

/// A tiny deterministic jitter buffer for half-duplex PTT.
/// It never retransmits live audio. Missing frames are concealed with a short silence frame so
/// late packets cannot stall the whole talk burst and increase end-to-end latency indefinitely.
struct VeilPTTJitterBuffer {
    let frameBytes: Int
    let targetDepth: Int
    let maximumBufferedFrames: Int
    let missingFramePatienceTicks: Int

    private var frames: [UInt32: Data] = [:]
    private var nextIndex: UInt32 = 0
    private var started = false
    private var ended = false
    private var missingTicks = 0

    private(set) var lateFrames = 0
    private(set) var duplicateFrames = 0
    private(set) var reorderedFrames = 0
    private(set) var concealedFrames = 0
    private(set) var overflowDrops = 0

    init(frameBytes: Int = 320, targetDepth: Int = 2, maximumBufferedFrames: Int = 8, missingFramePatienceTicks: Int = 1) {
        self.frameBytes = max(1, frameBytes)
        self.targetDepth = max(1, targetDepth)
        self.maximumBufferedFrames = max(self.targetDepth, maximumBufferedFrames)
        self.missingFramePatienceTicks = max(0, missingFramePatienceTicks)
    }

    mutating func reset() {
        frames.removeAll(keepingCapacity: true)
        nextIndex = 0
        started = false
        ended = false
        missingTicks = 0
        lateFrames = 0
        duplicateFrames = 0
        reorderedFrames = 0
        concealedFrames = 0
        overflowDrops = 0
    }

    @discardableResult
    mutating func push(index: UInt32, bytes: Data) -> Bool {
        guard !ended, !bytes.isEmpty, bytes.count <= frameBytes * 2 else { return false }
        guard index >= nextIndex else { lateFrames += 1; return false }
        guard frames[index] == nil else { duplicateFrames += 1; return false }

        if index > nextIndex { reorderedFrames += 1 }
        if frames.count >= maximumBufferedFrames {
            if let farthest = frames.keys.max(), index < farthest {
                frames.removeValue(forKey: farthest)
                overflowDrops += 1
            } else {
                overflowDrops += 1
                return false
            }
        }
        frames[index] = bytes
        if !started && frames.count >= targetDepth { started = true }
        return true
    }

    mutating func markEnded() {
        ended = true
        if !started && !frames.isEmpty { started = true }
    }

    mutating func nextForPlayout() -> VeilPTTPlayoutItem {
        guard started else { return ended && frames.isEmpty ? .finished : .wait }

        if let bytes = frames.removeValue(forKey: nextIndex) {
            nextIndex &+= 1
            missingTicks = 0
            return .frame(bytes)
        }

        if ended && frames.isEmpty { return .finished }
        let hasFuture = frames.keys.contains { $0 > nextIndex }
        guard hasFuture else { return ended ? .finished : .wait }

        missingTicks += 1
        if ended || missingTicks > missingFramePatienceTicks {
            nextIndex &+= 1
            missingTicks = 0
            concealedFrames += 1
            return .conceal(frameBytes: frameBytes)
        }
        return .wait
    }

    var snapshot: VeilPTTJitterSnapshot {
        VeilPTTJitterSnapshot(
            queuedFrames: frames.count,
            targetDepth: targetDepth,
            lateFrames: lateFrames,
            duplicateFrames: duplicateFrames,
            reorderedFrames: reorderedFrames,
            concealedFrames: concealedFrames,
            overflowDrops: overflowDrops
        )
    }
}
