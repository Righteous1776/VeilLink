import Foundation

/// Process-wide native backend lease for the on-device llama runtime.
/// A Swift actor protects one engine's pointers, but not another independent
/// runtime's llama_backend_init/llama_backend_free. The lease remains owned
/// from successful acquisition until that runtime has fully freed its model.
@MainActor
final class LlamaProcessLoadLease {
    static let shared = LlamaProcessLoadLease()

    private(set) var hasOwner = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var waitingCount: Int { waiters.count }

    func acquire() async {
        if !hasOwner {
            hasOwner = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
        // The previous owner transferred the lease directly to this waiter.
        // hasOwner remains true; no other runtime can initialize in between.
    }

    func release() {
        guard hasOwner else { return }
        if waiters.isEmpty {
            hasOwner = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
