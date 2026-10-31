import Foundation

/// Pure presentational projection, read-only from an existing session and timing frame.
/// The visual note lane never chooses the judged lane; gameplay remains in LiveConductor.
public enum VeilRhythmVisualTimeline {
    public struct VisibleNote: Equatable, Sendable {
        public let beat: Int
        public let lane: Int
        public let x, y: Double // canonical top-left 390x600 logical canvas
        public let secondsUntilHit: Double
    }
    public static let canvas = VeilRenderGeometry.Size(390, 600)
    public static let strikeY: Double = 500
    public static let spawnY: Double = 80
    public static let travelSeconds = 1.6

    /// The playback time axis comes from the injected monotonic host clock, not animation frame indices.
    public static func notes(seed: UInt64, district: Int, nextBeat: Int,
                             secondsToNextBeat: Double?, capacity: Int = 8) -> [VisibleNote] {
        guard let remaining = secondsToNextBeat, remaining.isFinite, (0..<4).contains(district),
              (0..<16).contains(nextBeat), (1...16).contains(capacity),
              let next = VeilRhythmExpedition.note(seed: seed, district: district, beat: nextBeat) else { return [] }
        var result: [VisibleNote] = []
        for beat in nextBeat..<min(16, nextBeat + capacity) {
            guard let note = VeilRhythmExpedition.note(seed: seed, district: district, beat: beat) else { break }
            let seconds = remaining + note.nominalTime - next.nominalTime
            guard seconds >= -0.18 && seconds <= travelSeconds else { continue }
            let unit = max(0, min(1, 1 - seconds / travelSeconds))
            let x = (Double(note.lane) + 0.5) * canvas.width / 4
            let y = spawnY + (strikeY - spawnY) * unit
            result.append(VisibleNote(beat: beat, lane: note.lane, x: x, y: y, secondsUntilHit: seconds))
        }
        return result
    }
}
