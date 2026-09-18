import Foundation

@MainActor
final class LocalTextModelCoordinator {
    private let runtime: LocalTextModelRuntime

    init(runtime: LocalTextModelRuntime) {
        self.runtime = runtime
    }

    var state: AgentRuntimeState { runtime.state }
    var manifest: LocalTextModelManifest? { runtime.manifest }

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

    func cancel() { runtime.cancel() }
    func trimMemory() { runtime.trimMemory() }
    func unload() { runtime.unload() }
}
