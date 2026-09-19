import Foundation

enum AgentPromptAssembler {
    static func makeRequest(
        session: AgentSession,
        userText: String,
        profile: AgentCapabilityProfile,
        visualContext: AgentVisualContext? = nil,
        localContext: AgentLocalContext? = nil,
        computeBudget: AgentLanguageComputeBudget? = nil
    ) -> AgentTextRequest {
        let cleaned = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        return AgentTextRequest(
            sessionID: session.id,
            messages: session.recentMessages(limit: computeBudget?.recentMessageLimit ?? profile.recentMessageLimit),
            userText: cleaned,
            maxNewTokens: computeBudget?.maxNewTokens ?? profile.maxNewTokens,
            visualContext: visualContext,
            localContext: localContext
        )
    }
}
