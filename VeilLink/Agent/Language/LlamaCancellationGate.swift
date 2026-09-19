import Foundation

#if canImport(llama)
final class LlamaCancellationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    func snapshot() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    func cancel() {
        lock.lock()
        generation &+= 1
        lock.unlock()
    }

    func isCurrent(_ snapshot: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == snapshot
    }
}
#endif
