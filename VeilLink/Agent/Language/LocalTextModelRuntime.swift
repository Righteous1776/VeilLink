import Foundation

@MainActor
protocol LocalTextModelRuntime: AgentRuntime {
    var manifest: LocalTextModelManifest? { get }

    func prepare() async throws
    func generate(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult
}
