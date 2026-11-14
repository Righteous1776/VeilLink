import Foundation

/// Shipping language backend is intentionally model-free. No GGUF model is
/// loaded, hashed, downloaded, or instantiated, even when a third-party
/// dependency accidentally exports a module named "llama".
@MainActor
enum LocalTextModelRuntimeFactory {
    static func make(profile: AgentCapabilityProfile) -> LocalTextModelRuntime {
        VeilTalkLiteRuntime()
    }

    nonisolated static var backendName: String { "VeilTalk Lite" }

    nonisolated static var isRealLocalInferenceCompiled: Bool { false }
}
