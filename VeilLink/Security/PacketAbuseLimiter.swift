import Foundation

struct PacketAbuseLimiter {
    struct Decision: Equatable {
        let isFirstInWindow: Bool
        let shouldDisconnect: Bool
        let count: Int
    }

    private struct Window {
        var startedAt: Date
        var count: Int
    }

    private var windows: [UUID: Window] = [:]
    private let windowDuration: TimeInterval
    private let maximumPacketsPerWindow: Int

    init(windowDuration: TimeInterval = 10, maximumPacketsPerWindow: Int = 8) {
        self.windowDuration = max(1, windowDuration)
        self.maximumPacketsPerWindow = max(1, maximumPacketsPerWindow)
    }

    mutating func recordInvalidPacket(for transportID: UUID, now: Date = Date()) -> Decision {
        var window = windows[transportID] ?? Window(startedAt: now, count: 0)
        if now.timeIntervalSince(window.startedAt) > windowDuration {
            window = Window(startedAt: now, count: 0)
        }
        window.count += 1
        windows[transportID] = window
        return Decision(
            isFirstInWindow: window.count == 1,
            shouldDisconnect: window.count >= maximumPacketsPerWindow,
            count: window.count
        )
    }

    mutating func reset(_ transportID: UUID) {
        windows.removeValue(forKey: transportID)
    }

    mutating func resetAll() {
        windows.removeAll(keepingCapacity: false)
    }
}
