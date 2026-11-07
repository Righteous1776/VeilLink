import Foundation

/// Log a *full* system snapshot only for meaningful brightness changes.
/// Main goal: avoid reading filesystem space and serializing diagnostic
/// metadata once per tiny automatic-brightness step on older devices.
enum DeepTelemetryBrightnessSnapshotPolicy {
    static let minimumInterval: TimeInterval = 2.0
    static let minimumBrightnessDelta: Double = 0.02

    static func shouldCapture(
        brightness: Double,
        previousBrightness: Double?,
        nowUptime: TimeInterval,
        previousUptime: TimeInterval?
    ) -> Bool {
        guard brightness.isFinite, (0.0...1.0).contains(brightness),
              nowUptime.isFinite else { return false }
        if let previousUptime {
            guard previousUptime.isFinite,
                  nowUptime >= previousUptime,
                  nowUptime - previousUptime >= minimumInterval else { return false }
        }
        if let previousBrightness {
            guard previousBrightness.isFinite,
                  (0.0...1.0).contains(previousBrightness),
                  abs(brightness - previousBrightness) >= minimumBrightnessDelta else { return false }
        }
        return true
    }
}
