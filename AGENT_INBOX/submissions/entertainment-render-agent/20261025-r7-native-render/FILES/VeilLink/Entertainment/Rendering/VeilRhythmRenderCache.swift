import Foundation

/// Precomputes chart metadata once per seed/district. SpriteKit reads bounded
/// value snapshots and never owns game rules, timing decisions or identities.
public struct VeilRhythmRenderCache: Sendable {
    /// Immutable seed used to generate the same sixteen notes on every replay.
    public let seed: UInt64
    /// Zero-based district, accepted range 0...3; never a remote peer identifier.
    public let district: Int
    private let schedule: [VeilRhythmExpedition.Note]
    /// Builds a fixed-size (16 note) cache; fails for unknown districts.
    /// No GPU nodes, timers, filesystem reads or network calls are created.
    public init?(seed: UInt64, district: Int) {
        guard (0..<4).contains(district) else { return nil }
        self.seed = seed
        self.district = district
        var items: [VeilRhythmExpedition.Note] = []
        for beat in 0..<16 {
            guard let n = VeilRhythmExpedition.note(seed: seed, district: district, beat: beat) else { return nil }
            items.append(n)
        }
        schedule = items
    }
    /// Computes at most `capacity` visible note placements without any allocation
    /// outside the returned value array. `secondsToNextBeat` may be negative
    /// inside the judgment window; NaN/infinite timestamps are rejected.
    public func visible(nextBeat: Int, secondsToNextBeat: Double,
                        capacity: Int = 5) -> [VeilRhythmVisualTimeline.VisibleNote] {
        guard (0..<16).contains(nextBeat), (1...16).contains(capacity),
              secondsToNextBeat.isFinite else { return [] }
        let nextTime = schedule[nextBeat].nominalTime
        let end = min(16, nextBeat + capacity)
        var visible: [VeilRhythmVisualTimeline.VisibleNote] = []
        visible.reserveCapacity(capacity)
        for beat in nextBeat..<end {
            let n = schedule[beat]
            let remaining = secondsToNextBeat + n.nominalTime - nextTime
            guard remaining >= -VeilRhythmLiveConductor.hitWindow,
                  remaining <= VeilRhythmVisualTimeline.travelSeconds else { continue }
            let progress = max(0, min(1, 1 - remaining / VeilRhythmVisualTimeline.travelSeconds))
            visible.append(.init(beat: beat, lane: n.lane,
                                 x: (Double(n.lane) + 0.5) * VeilRhythmVisualTimeline.canvas.width / 4,
                                 y: VeilRhythmVisualTimeline.spawnY +
                                    (VeilRhythmVisualTimeline.strikeY - VeilRhythmVisualTimeline.spawnY) * progress,
                                 secondsUntilHit: remaining))
        }
        return visible
    }
}

/// A stopped producer must not leave misleading, eternally frozen notes visible.
/// Paused content is held by design; running content goes blank until fresh data.
public enum VeilRenderSnapshotWatchdog {
    /// Clock classification: a running producer is stale after 280ms;
    /// `fresh(age)` is clamped to a nonnegative extrapolation interval.
    public enum Status: Equatable, Sendable { case fresh(Double), stale, invalid }
    /// The latest running snapshot is invalidated after 280ms without updates.
    public static let maximumRunningAge = 0.28
    /// Tolerate only 15ms of sampling skew; reject greater future timestamps.
    public static let maximumClockSkew = 0.015
    /// Evaluates two timestamps from the *same monotonic clock domain*.
    /// Paused state freezes intentionally; invalid numbers fail closed.
    /// The renderer must hide nodes on `stale` or `invalid`.
    public static func check(now: Double, sampledAt: Double, running: Bool) -> Status {
        guard now.isFinite, sampledAt.isFinite, now >= 0, sampledAt >= 0 else { return .invalid }
        let age = now - sampledAt
        guard age >= -maximumClockSkew else { return .invalid }
        if !running { return .fresh(0) }
        guard age <= maximumRunningAge else { return .stale }
        return .fresh(max(0, age))
    }
}
