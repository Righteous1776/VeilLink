import Foundation

/// Precomputes chart metadata once per seed/district. SpriteKit reads bounded
/// value snapshots and never owns game rules, timing decisions or identities.
public struct VeilRhythmRenderCache: Sendable {
    public let seed: UInt64
    public let district: Int
    private let schedule: [VeilRhythmExpedition.Note]
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
    public enum Status: Equatable, Sendable { case fresh(Double), stale, invalid }
    public static let maximumRunningAge = 0.28
    public static let maximumClockSkew = 0.015
    public static func check(now: Double, sampledAt: Double, running: Bool) -> Status {
        guard now.isFinite, sampledAt.isFinite, now >= 0, sampledAt >= 0 else { return .invalid }
        let age = now - sampledAt
        guard age >= -maximumClockSkew else { return .invalid }
        if !running { return .fresh(0) }
        guard age <= maximumRunningAge else { return .stale }
        return .fresh(max(0, age))
    }
}
