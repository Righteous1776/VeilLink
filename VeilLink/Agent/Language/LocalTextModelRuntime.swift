import Foundation

@MainActor
protocol LocalTextModelRuntime: AgentRuntime {
    var manifest: LocalTextModelManifest? { get }
    var backendName: String { get }

    func prepare() async throws
    func generate(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult
}


extension LocalTextModelRuntime {
    var backendName: String {
        manifest?.displayName ?? String(reflecting: type(of: self))
    }
}
