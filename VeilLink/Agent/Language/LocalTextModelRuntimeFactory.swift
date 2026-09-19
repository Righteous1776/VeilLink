import Foundation

#if REAL_LOCAL_AI_REQUIRED && !canImport(llama)
#error("REAL_LOCAL_AI_REQUIRED build cannot import the pinned llama.cpp module")
#endif

@MainActor
enum LocalTextModelRuntimeFactory {
    static func make(profile: AgentCapabilityProfile) -> LocalTextModelRuntime {
        #if canImport(llama)
        return LlamaLocalTextModelRuntime(profile: profile)
        #else
        return MockLocalTextModelRuntime()
        #endif
    }

    nonisolated static var backendName: String {
        #if canImport(llama)
        return "llama.cpp"
        #else
        return "foundation-mock"
        #endif
    }

    nonisolated static var isRealLocalInferenceCompiled: Bool {
        #if canImport(llama)
        return true
        #else
        return false
        #endif
    }
}
