import Foundation

/// E191 R5 rhythm timing core. Inject monotonic seconds from the host.
/// This type owns NO timers, audio session, BLE, SQLite or UI gesture recognizers.
/// Its schedule is gameplay timing, not an audio sample-accurate transport.
public struct VeilRhythmLiveConductor: Sendable {
    public typealias Game = VeilRhythmExpedition
    public static let leadIn: Double = 1.6
    public static let hitWindow: Double = 0.18

    public enum Failure: Error, Equatable {
        case invalidTime, notStarted, paused, invalidLane, tooEarly, inactive, stageNeedsTravel
    }
    public enum InputResult: Equatable {
        case hit(Game.Quality)
        case expired(Int)
    }
    public struct Frame: Equatable, Sendable {
        public let district: Int
        public let beat: Int
        public let expectedLane: Int?
        public let secondsToBeat: Double?
        public let progress: Double
        public let score: Int
        public let focus: Int
        public let running: Bool
        public let finished: Bool
    }

    public private(set) var session: Game.Session
    private var anchor: Double? = nil
    private var pausedAt: Double? = nil
    private var lastTime: Double? = nil

    public init(seed: UInt64) { self.session = Game.Session(seed: seed) }

    /// Fresh clock anchor at the NEXT pending beat. Earlier beats in a decoded
    /// snapshot are not silently re-judged; the caller must validate the snapshot.
    public init(session: Game.Session) { self.session = session }
    public var isRunning: Bool { anchor != nil && pausedAt == nil && session.phase == .playing }
    public var isPaused: Bool { pausedAt != nil }

    private mutating func observe(_ now: Double) throws {
        guard now.isFinite, now >= 0 else { throw Failure.invalidTime }
        guard lastTime.map({ now >= $0 }) ?? true else { throw Failure.invalidTime }
        lastTime = now
    }
    private func dueTime(for beat: Int) -> Double? {
        guard let anchor = anchor, let note = Game.note(seed: session.seed, district: session.district, beat: beat) else { return nil }
        return anchor + Self.leadIn + note.nominalTime
    }
    public mutating func start(at now: Double) throws {
        try observe(now)
        guard session.phase == .playing else { throw Failure.inactive }
        guard !session.districtCompleted else { throw Failure.stageNeedsTravel }
        guard anchor == nil else { return }
        let offset = session.expectedNote?.nominalTime ?? 0
        anchor = now - offset
    }
    public mutating func pause(at now: Double) throws {
        try observe(now)
        guard anchor != nil else { throw Failure.notStarted }
        if pausedAt == nil { pausedAt = now }
    }
    public mutating func resume(at now: Double) throws {
        try observe(now)
        guard let stoppedAt = pausedAt, let previousAnchor = anchor else { throw Failure.paused }
        anchor = previousAnchor + (now - stoppedAt)
        pausedAt = nil
    }
    /// Use this after app foreground return, never silently run missed beats in background.
    public mutating func travel(at now: Double) throws {
        try observe(now)
        guard session.phase == .playing else { throw Failure.inactive }
        guard session.districtCompleted else { throw Failure.stageNeedsTravel }
        do { try session.perform(.travel) }
        catch { throw Failure.stageNeedsTravel }
        anchor = nil
        pausedAt = nil
    }

    /// Deterministically consumes expired notes; no timers required.
    @discardableResult
    public mutating func advance(to now: Double) throws -> Int {
        try observe(now)
        guard isRunning else { return 0 }
        var expired = 0
        while session.phase == .playing && !session.districtCompleted,
              let due = dueTime(for: session.nextBeat), now - due > Self.hitWindow {
            let beat = session.nextBeat
            // Well-formed intentionally missed input, never credited as accurate.
            try session.perform(.tap(beat: beat, lane: session.expectedNote!.lane, offset: 1))
            expired += 1
        }
        return expired
    }
    /// Host must pass measured monotonic tap timestamp, NEVER a user-provided offset.
    public mutating func tap(lane: Int, at now: Double) throws -> InputResult {
        try observe(now)
        guard (0..<4).contains(lane) else { throw Failure.invalidLane }
        guard isRunning else { throw isPaused ? Failure.paused : Failure.notStarted }
        let expired = try advance(to: now)
        guard session.phase == .playing else { throw Failure.inactive }
        guard !session.districtCompleted else { return .expired(expired) }
        guard let due = dueTime(for: session.nextBeat) else { throw Failure.inactive }
        let offset = now - due
        guard offset >= -Self.hitWindow else { throw Failure.tooEarly }
        let next = session.nextBeat
        let event = try session.perform(.tap(beat: next, lane: lane, offset: offset))
        return .hit(event.quality ?? .miss)
    }
    public func frame(at now: Double) -> Frame {
        let seconds: Double?
        if let due = dueTime(for: session.nextBeat), now.isFinite {
            seconds = due - (pausedAt ?? now)
        } else { seconds = nil }
        return Frame(district: session.district, beat: session.nextBeat,
                     expectedLane: session.expectedNote?.lane,
                     secondsToBeat: seconds, progress: session.progress,
                     score: session.score, focus: session.focus,
                     running: isRunning, finished: session.phase != .playing)
    }
}
