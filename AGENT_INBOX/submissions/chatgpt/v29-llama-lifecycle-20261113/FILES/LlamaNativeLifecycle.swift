import Foundation

/// Models native llama pointer ownership across actor suspension points.
/// Actor isolation alone does NOT prevent reentry after await.
struct LlamaNativeLifecycle {
    enum Completion: Equatable {
        case noChange
        case trim
        case shutdown
    }

    private(set) var generating = false
    private(set) var trimPending = false
    private(set) var shutdownPending = false

    mutating func beginGeneration() -> Bool {
        guard !generating, !shutdownPending else { return false }
        generating = true
        return true
    }

    /// Returning false means the native operation must be deferred.
    mutating func requestTrim() -> Bool {
        guard !shutdownPending else { return false }
        guard generating else { return true }
        trimPending = true
        return false
    }

    /// Returning false means the caller must wait for generation to unwind.
    mutating func requestShutdown() -> Bool {
        guard generating else { return true }
        shutdownPending = true
        trimPending = false
        return false
    }

    mutating func finishGeneration() -> Completion {
        generating = false
        if shutdownPending {
            shutdownPending = false
            trimPending = false
            return .shutdown
        }
        if trimPending {
            trimPending = false
            return .trim
        }
        return .noChange
    }
}
