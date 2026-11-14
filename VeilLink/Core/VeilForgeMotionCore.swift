import Foundation

/// Visual actuation is discrete and deterministic. State indicators are never
/// fabricated throughput, search depth, message order, or other telemetry.
enum VeilForgeMotionCore {
    static let healthBarCount = 8

    /// Stepper rotor makes 48 detents (7.5°) per four-second cycle at 12 Hz.
    /// It parks instantly when the underlying subsystem is no longer working.
    static func rotorAngle(atSeconds seconds: TimeInterval, working: Bool) -> Double {
        guard working, seconds.isFinite else { return 0 }
        let phase = max(0, seconds).truncatingRemainder(dividingBy: 4)
        return floor(phase * 12) * 7.5
    }

    /// Routing carriage positions only reflect observed link counts:
    /// 0 = disconnected, 1 = TCP present, 2 = secure peer present.
    static func routeStage(connectedPeers: Int, securePeers: Int) -> Int {
        if securePeers > 0 { return 2 }
        if connectedPeers > 0 { return 1 }
        return 0
    }

    /// Only actual BLE health scores may be fed to this gauge (0...100).
    static func healthBars(_ score: Int) -> Int {
        let clamped = min(100, max(0, score))
        return (clamped * healthBarCount + 99) / 100
    }
}
