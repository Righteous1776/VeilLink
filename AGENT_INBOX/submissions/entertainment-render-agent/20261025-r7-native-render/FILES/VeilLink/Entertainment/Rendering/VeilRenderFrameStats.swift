import Foundation

/// Bounded, local-only update-callback cadence counters, not GPU timing.
/// Never records touch location, personal data, media or message content.
public struct VeilRenderFrameStats: Sendable {
    public struct Report: Equatable, Sendable {
        public let sampleCount: Int
        public let medianIntervalMs: Double
        public let p95IntervalMs: Double
        public let slowFrames: Int
        public let elapsedSeconds: Double
    }
    public static let maximumSamples = 240
    private var intervals: [Double] = []
    private var nextSlot = 0
    private var lastTime: Double?
    public init() { intervals.reserveCapacity(Self.maximumSamples) }
    public mutating func reset() {
        intervals.removeAll(keepingCapacity: true)
        nextSlot = 0
        lastTime = nil
    }
    /// Record only finite monotonic callback times; avoid counting background gaps.
    public mutating func observe(_ now: Double) {
        guard now.isFinite, now >= 0 else { return }
        guard let last = lastTime else { lastTime = now; return }
        guard now >= last else { lastTime = now; return }
        lastTime = now
        let delta = now - last
        guard delta > 0, delta <= 0.3 else { return }
        if intervals.count < Self.maximumSamples { intervals.append(delta) }
        else {
            intervals[nextSlot] = delta
            nextSlot = (nextSlot + 1) % Self.maximumSamples
        }
    }
    public var report: Report {
        let sorted = intervals.sorted()
        guard let middle = sorted.first else {
            return .init(sampleCount: 0, medianIntervalMs: 0,
                         p95IntervalMs: 0, slowFrames: 0, elapsedSeconds: 0)
        }
        let median = sorted[sorted.count/2]
        let p95 = sorted[min(sorted.count-1, Int(Double(sorted.count-1)*0.95 + 0.999999))]
        return .init(sampleCount: sorted.count,
                     medianIntervalMs: median * 1000,
                     p95IntervalMs: max(middle,p95) * 1000,
                     slowFrames: intervals.filter { $0 > 1.0/24.0 }.count,
                     elapsedSeconds: intervals.reduce(0,+))
    }
}
