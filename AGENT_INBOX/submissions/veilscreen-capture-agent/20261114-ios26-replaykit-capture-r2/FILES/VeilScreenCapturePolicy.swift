import Foundation

/// Selects supported public capture APIs, never probes private APIs or elevates privileges.
enum VeilScreenCaptureRoute: String {
    case replayKitBroadcastExtension
    case screenCaptureKit
    case unsupported

    static func select(iOSMajor: Int) -> Self {
        if iOSMajor >= 27 { return .screenCaptureKit }
        if iOSMajor >= 12 { return .replayKitBroadcastExtension }
        return .unsupported
    }
}

/// Capture capability and transport continuity are distinct facts.
enum VeilScreenDeliveryContinuity: Equatable {
    case unverified
    case foregroundOnly
    case backgroundVerified
}

/// Deterministic sampler: limit pixel work before compression, never accumulate frames.
struct VeilScreenCapturePacer {
    private(set) var lastEncodedAt: TimeInterval?
    private(set) var acceptedCount: UInt64 = 0
    private(set) var skippedCount: UInt64 = 0

    mutating func shouldEncode(at uptime: TimeInterval, minimumInterval: TimeInterval) -> Bool {
        guard uptime.isFinite, uptime >= 0, minimumInterval.isFinite,
              minimumInterval >= 0.25, minimumInterval <= 20 else {
            skippedCount &+= 1
            return false
        }
        if let previous = lastEncodedAt, uptime < previous || uptime - previous < minimumInterval {
            skippedCount &+= 1
            return false
        }
        lastEncodedAt = uptime
        acceptedCount &+= 1
        return true
    }

    mutating func reset() { lastEncodedAt = nil }
}

/// A session-local monotonic media freshness gate; obsolete frame data is discarded.
struct VeilScreenLatestFrameGate {
    private(set) var lastFrameID: UInt64?
    private(set) var lastAcceptedAt: TimeInterval?

    mutating func accept(frameID: UInt64, writtenAt: TimeInterval, now: TimeInterval,
                         maximumAge: TimeInterval = 8) -> Bool {
        guard writtenAt.isFinite, now.isFinite,
              writtenAt <= now + 2,
              now - writtenAt <= maximumAge,
              lastFrameID.map({ frameID > $0 }) ?? true else { return false }
        lastFrameID = frameID
        lastAcceptedAt = now
        return true
    }

    mutating func reset() { lastFrameID = nil; lastAcceptedAt = nil }
}
