import Combine
import Foundation

@MainActor
private final class AgentStreamingAccumulator {
    var text = ""
    var lastUIPublishNanoseconds: UInt64 = 0
}

@MainActor
final class AgentCoordinator: ObservableObject {
    @Published private(set) var session: AgentSession
    @Published private(set) var runtimeState: AgentRuntimeState
    @Published private(set) var diagnostics = AgentDiagnostics()
    @Published private(set) var lastError: String?
    @Published private(set) var visualContext: AgentVisualContext?
    @Published private(set) var visualContextEnabled = true
    @Published private(set) var computePlan: VeilA9ComputePlan

    let capabilityProfile: AgentCapabilityProfile
    private let language: LocalTextModelCoordinator
    private let computeGovernor: VeilA9ComputeGovernor
    private var generationTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var localContextProvider: (() -> AgentLocalContext?)?
    private var toolExecutor: ((String) -> AgentToolExecution?)?

    init(
        runtime: LocalTextModelRuntime? = nil,
        capabilityProfile: AgentCapabilityProfile = .current,
        computeGovernor: VeilA9ComputeGovernor? = nil
    ) {
        let selectedRuntime = runtime ?? LocalTextModelRuntimeFactory.make(profile: capabilityProfile)
        let governor = computeGovernor ?? VeilA9ComputeGovernor(profile: capabilityProfile)
        self.capabilityProfile = capabilityProfile
        self.computeGovernor = governor
        computePlan = governor.plan
        language = LocalTextModelCoordinator(runtime: selectedRuntime)
        runtimeState = selectedRuntime.state
        session = Self.makeFreshSession()
        governor.onPlanChanged = { [weak self] plan in
            self?.computePlan = plan
        }
    }

    func bindIntegration(
        localContextProvider: @escaping () -> AgentLocalContext?,
        toolExecutor: @escaping (String) -> AgentToolExecution?
    ) {
        self.localContextProvider = localContextProvider
        self.toolExecutor = toolExecutor
    }

    var runtimeManifest: LocalTextModelManifest? { language.manifest }
    var isGenerating: Bool { runtimeState == .generating }

    func activate() {
        guard language.state == .unloaded || language.state == .unavailable else {
            syncRuntimeState()
            return
        }
        guard preparationTask == nil else { return }
        preparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.preparationTask = nil }
            await self.prepareForUse()
        }
    }

    func prepareForUse() async {
        guard language.state == .unloaded || language.state == .unavailable else {
            syncRuntimeState()
            return
        }
        runtimeState = .loading
        do {
            try await language.prepareIfNeeded()
            diagnostics.prepareCount += 1
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            diagnostics.lastFailure = error.localizedDescription
        }
        syncRuntimeState()
    }

    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, generationTask == nil else { return }

        let user = AgentMessage(role: .user, text: text)
        session.append(user, limit: capabilityProfile.transcriptLimit)

        if let execution = toolExecutor?(text) {
            session.append(
                AgentMessage(role: .assistant, text: execution.message),
                limit: capabilityProfile.transcriptLimit
            )
            diagnostics.toolExecutionCount += 1
            diagnostics.lastToolCommand = execution.command
            diagnostics.lastFailure = nil
            return
        }

        let request = AgentPromptAssembler.makeRequest(
            session: session,
            userText: text,
            profile: capabilityProfile,
            visualContext: visualContext,
            localContext: localContextProvider?(),
            computeBudget: computePlan.language
        )
        let assistantID = UUID().uuidString
        session.append(AgentMessage(id: assistantID, role: .assistant, text: ""), limit: capabilityProfile.transcriptLimit)
        lastError = nil

        generationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let started = Date()
            self.runtimeState = .generating
            let stream = AgentStreamingAccumulator()
            let flushIntervalNanoseconds = UInt64(
                Self.streamingFlushIntervalMilliseconds(for: self.capabilityProfile.tier)
            ) * 1_000_000
            do {
                let result = try await self.language.generate(request: request) { [weak self] chunk in
                    guard let self else { return }
                    stream.text += chunk
                    let now = DispatchTime.now().uptimeNanoseconds
                    if stream.lastUIPublishNanoseconds == 0
                        || now &- stream.lastUIPublishNanoseconds >= flushIntervalNanoseconds {
                        self.session.updateMessage(id: assistantID, text: stream.text)
                        stream.lastUIPublishNanoseconds = now
                    }
                    self.runtimeState = .generating
                }
                self.session.updateMessage(id: assistantID, text: stream.text)
                self.diagnostics.generationCount += 1
                self.diagnostics.lastEstimatedTokenCount = result.estimatedTokenCount
                self.diagnostics.lastGenerationMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)
                self.diagnostics.lastFailure = nil
            } catch is CancellationError {
                self.diagnostics.cancellationCount += 1
                if stream.text.isEmpty {
                    self.session.removeMessage(id: assistantID)
                } else {
                    self.session.updateMessage(id: assistantID, text: stream.text)
                }
            } catch AgentRuntimeError.cancelled {
                self.diagnostics.cancellationCount += 1
                if stream.text.isEmpty {
                    self.session.removeMessage(id: assistantID)
                } else {
                    self.session.updateMessage(id: assistantID, text: stream.text)
                }
            } catch {
                self.lastError = error.localizedDescription
                self.diagnostics.lastFailure = error.localizedDescription
                if stream.text.isEmpty {
                    self.session.updateMessage(id: assistantID, text: "本地运行时暂时不可用：\(error.localizedDescription)")
                } else {
                    self.session.updateMessage(id: assistantID, text: stream.text)
                }
            }
            self.generationTask = nil
            self.syncRuntimeState()
        }
    }

    func stopGeneration() {
        guard generationTask != nil || runtimeState == .generating || runtimeState == .loading else { return }
        generationTask?.cancel()
        generationTask = nil
        preparationTask?.cancel()
        preparationTask = nil
        language.cancel()
        diagnostics.cancellationCount += 1
        syncRuntimeState()
    }


    func setVisualContextEnabled(_ enabled: Bool) {
        visualContextEnabled = enabled
        if !enabled { visualContext = nil }
    }

    func updateVisualContext(_ context: AgentVisualContext?) {
        visualContext = visualContextEnabled ? context : nil
    }

    func clearVisualContext() {
        visualContext = nil
    }

    func trimRuntimeMemory() {
        language.trimMemory()
        diagnostics.memoryTrimCount += 1
        syncRuntimeState()
    }

    func unloadRuntime() {
        stopGeneration()
        language.unload()
        diagnostics.unloadCount += 1
        visualContext = nil
        syncRuntimeState()
    }

    func newSession() {
        stopGeneration()
        session = Self.makeFreshSession()
        visualContext = nil
        lastError = nil
    }

    func handleMemoryPressure() {
        stopGeneration()
        language.trimMemory()
        diagnostics.memoryTrimCount += 1
        if capabilityProfile.unloadOnMemoryPressure {
            language.unload()
            diagnostics.unloadCount += 1
        }
        session.trim(to: min(capabilityProfile.transcriptLimit, max(8, computePlan.language.recentMessageLimit * 3)))
        visualContext = nil
        syncRuntimeState()
    }

    func handleBackground() {
        stopGeneration()
        if capabilityProfile.unloadOnBackground {
            language.unload()
            diagnostics.unloadCount += 1
        } else {
            language.trimMemory()
            diagnostics.memoryTrimCount += 1
        }
        visualContext = nil
        syncRuntimeState()
    }


    func setComputeFocus(_ focus: AgentComputeFocus) {
        computeGovernor.setFocus(focus)
    }

    func computeDiagnosticsReport() -> String {
        computeGovernor.report()
    }

    func diagnosticsReport() -> String {
        diagnostics.report(
            runtimeState: runtimeState,
            runtimeID: runtimeManifest?.id ?? "none",
            profile: capabilityProfile,
            sessionMessageCount: session.messages.count
        ) + "\n\n" + computeGovernor.report()
    }

    nonisolated static func streamingFlushIntervalMilliseconds(
        for tier: AgentComputeTier
    ) -> Int {
        switch tier {
        case .legacyA10: return 50
        case .balanced: return 35
        case .high: return 25
        }
    }

    private func syncRuntimeState() {
        runtimeState = language.state
    }

    private static func makeFreshSession() -> AgentSession {
        AgentSession(messages: [
            AgentMessage(
                role: .assistant,
                text: "灵核在本机待命。当前运行时：\(LocalTextModelRuntimeFactory.backendName)。Core 版使用零模型本地对话规则；实验 AI 版可单独启用 llama/Qwen。"
            )
        ])
    }
}
