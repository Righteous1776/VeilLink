import Foundation

@MainActor
final class LocalTextModelCoordinator {
    private let baseRuntime: LocalTextModelRuntime
    private var runtime: LocalTextModelRuntime

    init(runtime: LocalTextModelRuntime) {
        baseRuntime = runtime
        self.runtime = runtime
    }

    var state: AgentRuntimeState { runtime.state }
    var manifest: LocalTextModelManifest? { runtime.manifest }
    var backendName: String { runtime.backendName }
    var isUsingOverride: Bool { runtime !== baseRuntime }

    func prepareIfNeeded() async throws {
        if runtime.state == .unloaded || runtime.state == .unavailable {
            try await runtime.prepare()
        }
    }

    func generate(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult {
        try await prepareIfNeeded()
        return try await runtime.generate(request: request, onToken: onToken)
    }

    /// Replaces only the compute backend. LingCore session, tool routing and host authority remain
    /// in AgentCoordinator / AppModel. The previous override is unloaded before replacement.
    func activateOverride(_ next: LocalTextModelRuntime) {
        guard runtime !== next else { return }
        runtime.cancel()
        runtime.unload()
        runtime = next
    }

    /// Restores the original local runtime. The base runtime may be unloaded and will lazily
    /// prepare on the next request.
    func restoreBaseRuntime() {
        guard runtime !== baseRuntime else { return }
        runtime.cancel()
        runtime.unload()
        runtime = baseRuntime
    }

    func cancel() { runtime.cancel() }
    func trimMemory() { runtime.trimMemory() }
    func unload() { runtime.unload() }
}
