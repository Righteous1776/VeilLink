import Foundation

/// Tracks the gap between an established CoreBluetooth physical connection and
/// the first usable GATT data notification. Uses monotonic process uptime at
/// call sites, not wall-clock time, and intentionally does not own a timer.
struct BLEGattHandshakeWatchdog {
    static let defaultTimeout: TimeInterval = 45

    private var pendingSince: [UUID: TimeInterval] = [:]

    var pendingCount: Int { pendingSince.count }

    mutating func physicalLinkConnected(_ peerID: UUID, uptime: TimeInterval) {
        guard uptime.isFinite, uptime >= 0 else { return }
        pendingSince[peerID] = uptime
    }

    mutating func dataChannelReady(_ peerID: UUID) {
        pendingSince.removeValue(forKey: peerID)
    }

    mutating func disconnected(_ peerID: UUID) {
        pendingSince.removeValue(forKey: peerID)
    }

    mutating func resetAll() {
        pendingSince.removeAll(keepingCapacity: false)
    }

    func timedOutPeerIDs(
        uptime: TimeInterval,
        timeout: TimeInterval = Self.defaultTimeout
    ) -> [UUID] {
        guard uptime.isFinite, timeout.isFinite, timeout > 0 else { return [] }
        return pendingSince.compactMap { peerID, since in
            let elapsed = uptime - since
            return elapsed.isFinite && elapsed >= timeout ? peerID : nil
        }.sorted { $0.uuidString < $1.uuidString }
    }
}
