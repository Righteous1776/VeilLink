import Foundation

/// A conversation-only inlet for an untrusted, small language model.
/// This type deliberately has no reference to AppModel, AgentCoordinator,
/// AgentToolRouter, control-plane services, game engines, or database stores.
@MainActor
final class LingCoreChatOnlyBoundary {
    private let runtime: LocalTextModelRuntime
    private var session = AgentSession()
    private(set) var isGenerating = false
    private var generationRevision: UInt64 = 0

    init(runtime: LocalTextModelRuntime) {
        self.runtime = runtime
    }

    var modelName: String { runtime.backendName }
    var messageCount: Int { session.messages.count }

    /// Only text typed into this dedicated channel may cross the boundary.
    /// The model cannot receive device state, keys, link metadata, diagnostics,
    /// game state, app-control capabilities or calls to action tools.
    func reply(
        to text: String,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= 512, !isGenerating else {
            throw AgentRuntimeError.invalidRequest
        }
        isGenerating = true
        let capturedRevision = generationRevision
        defer { isGenerating = false }

        let user = AgentMessage(role: .user, text: input)
        session.append(user, limit: 6)

        let request = AgentTextRequest(
            sessionID: session.id,
            messages: session.recentMessages(limit: 6),
            userText: input,
            maxNewTokens: 96,
            visualContext: nil,
            localContext: nil
        )

        do {
            if runtime.state == .unloaded || runtime.state == .unavailable {
                try await runtime.prepare()
            }
            guard capturedRevision == generationRevision else { throw AgentRuntimeError.cancelled }
            let result = try await runtime.generate(request: request, onToken: onToken)
            guard capturedRevision == generationRevision else { throw AgentRuntimeError.cancelled }
            session.append(
                AgentMessage(role: .assistant, text: String(result.text.prefix(4_096))),
                limit: 6
            )
            return result.text
        } catch {
            // Failed generations do not grant any fallback to privileged lanes.
            throw error
        }
    }

    func cancel() {
        generationRevision &+= 1
        runtime.cancel()
    }

    func clear() {
        generationRevision &+= 1
        runtime.cancel()
        session = AgentSession()
    }
}
