import Combine
import Foundation
import UIKit

extension Notification.Name {
    static let veilLinkStressUICommand = Notification.Name("VeilLink.DeviceStress.UICommand")
}

enum DeviceStressUICommand: String, Codable {
    case settingsOpenIdentity
    case settingsOpenAppLock
    case settingsOpenBackup
    case settingsClosePresentations
    case agentOpenDiagnostics
    case agentCloseDiagnostics
    case chatOpenFirstConversation
    case chatCloseConversation
}

enum DeviceStressCommandBus {
    static func post(_ command: DeviceStressUICommand) {
        NotificationCenter.default.post(
            name: .veilLinkStressUICommand,
            object: nil,
            userInfo: ["command": command.rawValue]
        )
    }

    static func command(from notification: Notification) -> DeviceStressUICommand? {
        guard let raw = notification.userInfo?["command"] as? String else { return nil }
        return DeviceStressUICommand(rawValue: raw)
    }
}

enum DeviceStressPreset: String, CaseIterable, Codable, Identifiable {
    case quick
    case standard
    case extreme
    case endurance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "快速巡检"
        case .standard: return "标准压力"
        case .extreme: return "极速轰炸"
        case .endurance: return "持续烧机"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "3 轮 · 180 ms/步 · 适合每次新 IPA 首测"
        case .standard: return "20 轮 · 90 ms/步 · UI/存储/Agent/链路综合"
        case .extreme: return "100 轮 · 35 ms/步 · 高频状态切换与事件风暴"
        case .endurance: return "持续运行直到手动停止或安全熔断"
        }
    }

    var defaultCycles: Int {
        switch self {
        case .quick: return 3
        case .standard: return 20
        case .extreme: return 100
        case .endurance: return 0
        }
    }

    var defaultDelayMilliseconds: Int {
        switch self {
        case .quick: return 180
        case .standard: return 90
        case .extreme: return 35
        case .endurance: return 120
        }
    }
}

struct DeviceStressConfiguration: Codable, Equatable {
    var preset: DeviceStressPreset
    var requestedCycles: Int
    var stepDelayMilliseconds: Int
    var exercisePresentations: Bool
    var exerciseBLEChurn: Bool
    var exerciseStorageIntegrity: Bool
    var exerciseAgentAndMaleCNS: Bool
    var exerciseMemoryPressure: Bool
    var captureEveryStep: Bool

    static func defaults(for preset: DeviceStressPreset) -> DeviceStressConfiguration {
        DeviceStressConfiguration(
            preset: preset,
            requestedCycles: preset.defaultCycles,
            stepDelayMilliseconds: preset.defaultDelayMilliseconds,
            exercisePresentations: true,
            exerciseBLEChurn: preset == .standard || preset == .extreme || preset == .endurance,
            exerciseStorageIntegrity: true,
            exerciseAgentAndMaleCNS: true,
            exerciseMemoryPressure: preset == .extreme || preset == .endurance,
            captureEveryStep: true
        )
    }
}

enum DeviceStressStepOutcome: String, Codable {
    case passed
    case skipped
    case failed
    case interrupted
}

struct DeviceStressStepResult: Codable, Identifiable {
    let id: String
    let sequence: Int
    let cycle: Int
    let name: String
    let startedAt: Date
    let durationMilliseconds: Int
    let outcome: DeviceStressStepOutcome
    let detail: String
    let screen: String
    let thermalState: String
}

struct DeviceStressSummary: Codable {
    let format: String
    let version: Int
    let sessionID: String
    let preset: DeviceStressPreset
    let configuration: DeviceStressConfiguration
    let startedAt: Date
    let finishedAt: Date
    let elapsedMilliseconds: Int
    let stopReason: String
    let completedCycles: Int
    let completedSteps: Int
    let passedSteps: Int
    let skippedSteps: Int
    let failedSteps: Int
    let memoryWarnings: Int
    let baselineSection: String
    let baselineBLERunning: Bool
    let finalThermalState: String
    let finalBatteryLevel: String
}

private enum StressDisposition {
    case passed(String)
    case skipped(String)
}

@MainActor
final class DeviceStressTestController: ObservableObject {
    static let shared = DeviceStressTestController()

    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var sessionID = "-"
    @Published private(set) var currentCycle = 0
    @Published private(set) var currentStep = "idle"
    @Published private(set) var completedSteps = 0
    @Published private(set) var passedSteps = 0
    @Published private(set) var skippedSteps = 0
    @Published private(set) var failedSteps = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var stopReason = "idle"
    @Published private(set) var memoryWarningCount = 0
    @Published private(set) var lastExportURL: URL?
    @Published private(set) var lastSummary: DeviceStressSummary?

    @Published var configuration = DeviceStressConfiguration.defaults(for: .standard)

    private weak var model: AppModel?
    private var task: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var requestedStopReason: String?
    private var startedAt: Date?
    private var stepSequence = 0
    private var stepResults: [DeviceStressStepResult] = []
    private var baselineSection: SidebarSection = .chats
    private var baselineConversation: ConversationSummary?
    private var baselineBLERunning = false
    private var recoveredCheckpoint = false

    private let store = DiagnosticLogStore.shared
    private let defaults = UserDefaults.standard

    private static let checkpointSessionKey = "diagnostics.stress.active_session"
    private static let checkpointPresetKey = "diagnostics.stress.preset"
    private static let checkpointCycleKey = "diagnostics.stress.cycle"
    private static let checkpointStepKey = "diagnostics.stress.step"
    private static let checkpointStartedKey = "diagnostics.stress.started_at"

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func attach(model: AppModel) {
        self.model = model
        recoverIncompleteCheckpointIfNeeded()
    }

    func applyPresetDefaults(_ preset: DeviceStressPreset) {
        guard !isRunning else { return }
        configuration = .defaults(for: preset)
    }

    func start(model: AppModel) {
        guard !isRunning else { return }
        attach(model: model)

        let config = normalized(configuration)
        configuration = config
        baselineSection = model.selectedSection
        baselineConversation = model.selectedConversation
        baselineBLERunning = model.bluetooth.isRunning
        sessionID = String(UUID().uuidString.prefix(12)).uppercased()
        currentCycle = 0
        currentStep = "preflight"
        completedSteps = 0
        passedSteps = 0
        skippedSteps = 0
        failedSteps = 0
        elapsedSeconds = 0
        stopReason = "running"
        memoryWarningCount = 0
        lastExportURL = nil
        lastSummary = nil
        stepSequence = 0
        stepResults.removeAll(keepingCapacity: true)
        requestedStopReason = nil
        startedAt = Date()
        isPaused = false
        isRunning = true

        persistCheckpoint()
        log(
            .info,
            event: "stress.session.begin",
            metadata: [
                "stress_session": sessionID,
                "preset": config.preset.rawValue,
                "cycles": config.requestedCycles == 0 ? "until-stop" : String(config.requestedCycles),
                "step_delay_ms": String(config.stepDelayMilliseconds),
                "ble_churn": String(config.exerciseBLEChurn),
                "presentations": String(config.exercisePresentations),
                "storage_integrity": String(config.exerciseStorageIntegrity),
                "agent_malecns": String(config.exerciseAgentAndMaleCNS),
                "memory_pressure": String(config.exerciseMemoryPressure)
            ]
        )
        RuntimeDiagnosticsBridge.shared.captureIncidentSnapshot(for: model, reason: "stress.begin")

        startElapsedTicker()
        task = Task { @MainActor [weak self, weak model] in
            guard let self, let model else { return }
            await self.run(model: model, configuration: config)
        }
    }

    func togglePause() {
        guard isRunning else { return }
        isPaused.toggle()
        log(
            .info,
            event: isPaused ? "stress.session.paused" : "stress.session.resumed",
            metadata: ["stress_session": sessionID, "cycle": String(currentCycle), "step": currentStep]
        )
    }

    func stop(reason: String = "user_stop") {
        guard isRunning else { return }
        requestedStopReason = reason
        log(.warning, event: "stress.stop.requested", metadata: ["reason": reason, "stress_session": sessionID])
        task?.cancel()
    }

    func handleSceneActive(_ active: Bool) {
        guard isRunning, !active else { return }
        stop(reason: "app_left_foreground")
    }

    func noteMemoryWarning() {
        guard isRunning else { return }
        memoryWarningCount += 1
        log(
            .warning,
            event: "stress.memory_warning",
            metadata: ["count": String(memoryWarningCount), "stress_session": sessionID]
        )
        if memoryWarningCount >= 2 {
            stop(reason: "repeated_memory_warning")
        }
    }

    func clearLastExport() {
        lastExportURL = nil
    }

    private func run(model: AppModel, configuration: DeviceStressConfiguration) async {
        var loop = 0
        var terminalReason = "completed"

        while !Task.isCancelled {
            await waitWhilePaused()
            if Task.isCancelled { break }

            if let reason = safetyStopReason() {
                terminalReason = reason
                break
            }

            loop += 1
            currentCycle = loop
            persistCheckpoint()
            log(
                .info,
                event: "stress.cycle.begin",
                metadata: ["stress_session": sessionID, "cycle": String(loop)]
            )

            await runCycle(loop, model: model, configuration: configuration)
            if Task.isCancelled { break }

            log(
                .info,
                event: "stress.cycle.end",
                metadata: [
                    "stress_session": sessionID,
                    "cycle": String(loop),
                    "passed": String(passedSteps),
                    "failed": String(failedSteps),
                    "skipped": String(skippedSteps)
                ]
            )

            if ProcessInfo.processInfo.thermalState == .serious {
                log(.warning, event: "stress.thermal.cooldown", metadata: ["seconds": "2"])
                await sleep(milliseconds: 2_000)
            }

            if configuration.requestedCycles > 0, loop >= configuration.requestedCycles {
                terminalReason = failedSteps > 0 ? "completed_with_failures" : "completed"
                break
            }
        }

        if Task.isCancelled {
            terminalReason = requestedStopReason ?? "cancelled"
        } else if let requestedStopReason {
            terminalReason = requestedStopReason
        }

        await finish(model: model, configuration: configuration, reason: terminalReason)
    }

    private func runCycle(_ cycle: Int, model: AppModel, configuration: DeviceStressConfiguration) async {
        await step("ui.tabs.chats", cycle: cycle, configuration: configuration) {
            model.selectedSection = .chats
            model.selectedConversation = nil
            return .passed("selected chats")
        }

        await step("ui.chat.open", cycle: cycle, configuration: configuration, delayMultiplier: 2.0) {
            guard !model.conversations.isEmpty else { return .skipped("no conversation available") }
            DeviceStressCommandBus.post(.chatOpenFirstConversation)
            return .passed("requested first conversation presentation")
        }
        await step("ui.chat.close", cycle: cycle, configuration: configuration) {
            DeviceStressCommandBus.post(.chatCloseConversation)
            model.selectedConversation = nil
            return .passed("chat presentation cleared")
        }

        await step("ui.tabs.nearby", cycle: cycle, configuration: configuration) {
            model.selectedSection = .nearby
            return .passed("selected nearby")
        }
        await step("ble.refresh", cycle: cycle, configuration: configuration) {
            model.bluetooth.refreshLinks()
            return .passed("link snapshots refreshed")
        }

        if configuration.exerciseBLEChurn {
            await step("ble.churn.flip", cycle: cycle, configuration: configuration, delayMultiplier: 2.0) {
                if model.bluetooth.isRunning {
                    model.bluetooth.stop()
                    return .passed("transport stopped")
                } else {
                    model.bluetooth.start()
                    return .passed("transport started")
                }
            }
            await step("ble.churn.restore", cycle: cycle, configuration: configuration, delayMultiplier: 2.0) {
                if self.baselineBLERunning, !model.bluetooth.isRunning {
                    model.bluetooth.start()
                } else if !self.baselineBLERunning, model.bluetooth.isRunning {
                    model.bluetooth.stop()
                }
                return .passed("transport baseline restored")
            }
        }

        await step("ui.tabs.settings", cycle: cycle, configuration: configuration) {
            model.selectedSection = .settings
            return .passed("selected settings")
        }

        if configuration.exercisePresentations {
            await presentationStep("ui.settings.identity_sheet", open: .settingsOpenIdentity, close: .settingsClosePresentations, cycle: cycle, configuration: configuration)
            await presentationStep("ui.settings.lock_sheet", open: .settingsOpenAppLock, close: .settingsClosePresentations, cycle: cycle, configuration: configuration)
            await presentationStep("ui.settings.backup_sheet", open: .settingsOpenBackup, close: .settingsClosePresentations, cycle: cycle, configuration: configuration)
        }

        if configuration.exerciseStorageIntegrity {
            await step("storage.integrity", cycle: cycle, configuration: configuration, delayMultiplier: 1.5) {
                let result = model.database.integrityCheck().trimmingCharacters(in: .whitespacesAndNewlines)
                model.runA9StorageCheck()
                if result.lowercased() == "ok" {
                    return .passed("sqlite integrity ok")
                }
                throw StressFailure("SQLite integrity returned: \(result)")
            }
        }

        await step("a9.refresh", cycle: cycle, configuration: configuration) {
            model.refreshA9Health()
            return .passed("A9 sampled")
        }

        await step("ui.tabs.agent", cycle: cycle, configuration: configuration) {
            model.selectedSection = .agent
            return .passed("selected agent")
        }

        if configuration.exerciseAgentAndMaleCNS {
            await step("agent.activate", cycle: cycle, configuration: configuration, delayMultiplier: 1.5) {
                model.agent.activate()
                return .passed("agent activation requested")
            }
            if configuration.exercisePresentations {
                await presentationStep("ui.agent.diagnostics_sheet", open: .agentOpenDiagnostics, close: .agentCloseDiagnostics, cycle: cycle, configuration: configuration)
            }
            await step("malecns.prepare", cycle: cycle, configuration: configuration, delayMultiplier: 1.5) {
                model.maleCNS.prepareFromBundle()
                return .passed("MaleCNS prepare requested: \(model.maleCNS.state.displayName)")
            }
            await step("malecns.trim", cycle: cycle, configuration: configuration) {
                model.maleCNS.trim()
                return .passed("MaleCNS transient compute state trimmed")
            }
        }

        await step("model.reload_conversations", cycle: cycle, configuration: configuration) {
            model.reloadConversations()
            return .passed("conversation summaries reloaded")
        }

        await step("ui.rapid_tab_churn", cycle: cycle, configuration: configuration, delayMultiplier: 0.25) {
            model.selectedSection = .chats
            model.selectedSection = .nearby
            model.selectedSection = .agent
            model.selectedSection = .settings
            model.selectedSection = .chats
            return .passed("five section assignments")
        }

        if configuration.exerciseMemoryPressure, cycle % 5 == 0 {
            await step("runtime.memory_trim", cycle: cycle, configuration: configuration, delayMultiplier: 2.0) {
                model.handleMemoryPressure()
                return .passed("memory-pressure cleanup path exercised")
            }
        }

        await step("blackbox.cycle_snapshot", cycle: cycle, configuration: configuration) {
            RuntimeDiagnosticsBridge.shared.captureIncidentSnapshot(for: model, reason: "stress.cycle.\(cycle)")
            return .passed("incident snapshot captured")
        }
    }

    private func presentationStep(
        _ name: String,
        open: DeviceStressUICommand,
        close: DeviceStressUICommand,
        cycle: Int,
        configuration: DeviceStressConfiguration
    ) async {
        await step(name + ".open", cycle: cycle, configuration: configuration, delayMultiplier: 2.0) {
            DeviceStressCommandBus.post(open)
            return .passed("presentation open requested")
        }
        await step(name + ".close", cycle: cycle, configuration: configuration, delayMultiplier: 1.5) {
            DeviceStressCommandBus.post(close)
            return .passed("presentation close requested")
        }
    }

    private func step(
        _ name: String,
        cycle: Int,
        configuration: DeviceStressConfiguration,
        delayMultiplier: Double = 1.0,
        action: () throws -> StressDisposition
    ) async {
        guard !Task.isCancelled else { return }
        await waitWhilePaused()
        guard !Task.isCancelled else { return }

        if let reason = safetyStopReason() {
            requestedStopReason = reason
            task?.cancel()
            return
        }

        stepSequence += 1
        currentStep = name
        persistCheckpoint()
        let sequence = stepSequence
        let started = Date()
        let uptimeStart = ProcessInfo.processInfo.systemUptime
        log(
            .debug,
            event: "stress.step.begin",
            metadata: [
                "stress_session": sessionID,
                "step_sequence": String(sequence),
                "cycle": String(cycle),
                "step": name
            ]
        )

        let outcome: DeviceStressStepOutcome
        let detail: String
        do {
            switch try action() {
            case .passed(let message):
                outcome = .passed
                detail = message
                passedSteps += 1
            case .skipped(let message):
                outcome = .skipped
                detail = message
                skippedSteps += 1
            }
        } catch {
            outcome = .failed
            detail = error.localizedDescription
            failedSteps += 1
        }

        completedSteps += 1
        let duration = Int((ProcessInfo.processInfo.systemUptime - uptimeStart) * 1_000)
        let result = DeviceStressStepResult(
            id: UUID().uuidString,
            sequence: sequence,
            cycle: cycle,
            name: name,
            startedAt: started,
            durationMilliseconds: duration,
            outcome: outcome,
            detail: detail,
            screen: DeepTelemetry.shared.currentScreen,
            thermalState: Self.thermalState(ProcessInfo.processInfo.thermalState)
        )
        stepResults.append(result)
        if stepResults.count > 10_000 {
            stepResults.removeFirst(stepResults.count - 10_000)
        }

        log(
            outcome == .failed ? .error : (outcome == .skipped ? .debug : .info),
            event: "stress.step.\(outcome.rawValue)",
            metadata: [
                "stress_session": sessionID,
                "step_sequence": String(sequence),
                "cycle": String(cycle),
                "step": name,
                "duration_ms": String(duration),
                "detail": detail,
                "thermal": result.thermalState
            ]
        )

        if configuration.captureEveryStep {
            DeepTelemetry.shared.captureUIHierarchy(reason: "stress.\(name)", force: true)
        }

        let delay = max(15, Int(Double(configuration.stepDelayMilliseconds) * delayMultiplier))
        await sleep(milliseconds: delay)
    }

    private func finish(model: AppModel, configuration: DeviceStressConfiguration, reason: String) async {
        DeviceStressCommandBus.post(.settingsClosePresentations)
        DeviceStressCommandBus.post(.agentCloseDiagnostics)
        DeviceStressCommandBus.post(.chatCloseConversation)

        model.selectedSection = baselineSection
        model.selectedConversation = baselineConversation
        if baselineBLERunning, !model.bluetooth.isRunning {
            model.bluetooth.start()
        } else if !baselineBLERunning, model.bluetooth.isRunning {
            model.bluetooth.stop()
        }

        let finished = Date()
        let start = startedAt ?? finished
        let elapsedMs = max(0, Int(finished.timeIntervalSince(start) * 1_000))
        let finalReason = reason
        stopReason = finalReason
        currentStep = "finished"

        let summary = DeviceStressSummary(
            format: "VeilLinkDeviceStress",
            version: 1,
            sessionID: sessionID,
            preset: configuration.preset,
            configuration: configuration,
            startedAt: start,
            finishedAt: finished,
            elapsedMilliseconds: elapsedMs,
            stopReason: finalReason,
            completedCycles: currentCycle,
            completedSteps: completedSteps,
            passedSteps: passedSteps,
            skippedSteps: skippedSteps,
            failedSteps: failedSteps,
            memoryWarnings: memoryWarningCount,
            baselineSection: baselineSection.rawValue,
            baselineBLERunning: baselineBLERunning,
            finalThermalState: Self.thermalState(ProcessInfo.processInfo.thermalState),
            finalBatteryLevel: Self.batteryLevelText()
        )
        lastSummary = summary

        log(
            failedSteps > 0 ? .warning : .info,
            event: "stress.session.end",
            metadata: [
                "stress_session": sessionID,
                "reason": finalReason,
                "cycles": String(currentCycle),
                "steps": String(completedSteps),
                "passed": String(passedSteps),
                "skipped": String(skippedSteps),
                "failed": String(failedSteps),
                "elapsed_ms": String(elapsedMs)
            ]
        )
        RuntimeDiagnosticsBridge.shared.captureIncidentSnapshot(for: model, reason: "stress.end")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let summaryData = try encoder.encode(summary)
            let stepsData = try encoder.encode(stepResults)
            let readable = makeReadableReport(summary: summary)
            lastExportURL = try RuntimeDiagnosticsBridge.shared.exportBundle(
                for: model,
                reason: "stress.auto_export",
                extraFiles: [
                    "stress-summary.json": summaryData,
                    "stress-steps.json": stepsData,
                    "stress-report.txt": Data(readable.utf8)
                ]
            )
        } catch {
            log(.error, event: "stress.export.failed", metadata: ["error": error.localizedDescription])
        }

        clearCheckpoint()
        tickTask?.cancel()
        tickTask = nil
        task = nil
        requestedStopReason = nil
        isPaused = false
        isRunning = false
    }

    private func normalized(_ value: DeviceStressConfiguration) -> DeviceStressConfiguration {
        var result = value
        result.requestedCycles = min(10_000, max(0, result.requestedCycles))
        result.stepDelayMilliseconds = min(2_000, max(15, result.stepDelayMilliseconds))
        if result.preset == .endurance { result.requestedCycles = 0 }
        return result
    }

    private func safetyStopReason() -> String? {
        if UIApplication.shared.applicationState != .active {
            return "app_not_foreground"
        }
        if ProcessInfo.processInfo.thermalState == .critical {
            return "thermal_critical"
        }
        let device = UIDevice.current
        if device.batteryLevel >= 0,
           device.batteryLevel < 0.05,
           device.batteryState == .unplugged {
            return "battery_below_5_percent"
        }
        return nil
    }

    private func waitWhilePaused() async {
        while isPaused, !Task.isCancelled {
            await sleep(milliseconds: 100)
        }
    }

    private func sleep(milliseconds: Int) async {
        guard milliseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }

    private func startElapsedTicker() {
        tickTask?.cancel()
        tickTask = Task { @MainActor [weak self] in
            while let self, self.isRunning, !Task.isCancelled {
                if let startedAt = self.startedAt {
                    self.elapsedSeconds = Date().timeIntervalSince(startedAt)
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func persistCheckpoint() {
        defaults.set(sessionID, forKey: Self.checkpointSessionKey)
        defaults.set(configuration.preset.rawValue, forKey: Self.checkpointPresetKey)
        defaults.set(currentCycle, forKey: Self.checkpointCycleKey)
        defaults.set(currentStep, forKey: Self.checkpointStepKey)
        if let startedAt {
            defaults.set(startedAt.timeIntervalSince1970, forKey: Self.checkpointStartedKey)
        }
    }

    private func clearCheckpoint() {
        defaults.removeObject(forKey: Self.checkpointSessionKey)
        defaults.removeObject(forKey: Self.checkpointPresetKey)
        defaults.removeObject(forKey: Self.checkpointCycleKey)
        defaults.removeObject(forKey: Self.checkpointStepKey)
        defaults.removeObject(forKey: Self.checkpointStartedKey)
    }

    private func recoverIncompleteCheckpointIfNeeded() {
        guard !recoveredCheckpoint else { return }
        recoveredCheckpoint = true
        guard let prior = defaults.string(forKey: Self.checkpointSessionKey), !prior.isEmpty else { return }
        let preset = defaults.string(forKey: Self.checkpointPresetKey) ?? "unknown"
        let cycle = defaults.integer(forKey: Self.checkpointCycleKey)
        let step = defaults.string(forKey: Self.checkpointStepKey) ?? "unknown"
        let started = defaults.double(forKey: Self.checkpointStartedKey)
        store.log(
            .critical,
            .stress,
            event: "stress.previous_session_incomplete",
            screen: DeepTelemetry.shared.currentScreen,
            metadata: [
                "stress_session": prior,
                "preset": preset,
                "last_cycle": String(cycle),
                "last_step": step,
                "started_at_epoch": String(format: "%.3f", started),
                "interpretation": "previous burn-in session did not reach normal finalization; inspect preceding logs for crash, termination, watchdog, memory or manual kill"
            ]
        )
        clearCheckpoint()
    }

    private func log(_ level: DiagnosticLogLevel, event: String, metadata: [String: String] = [:]) {
        store.log(level, .stress, event: event, screen: DeepTelemetry.shared.currentScreen, metadata: metadata)
    }

    private func makeReadableReport(summary: DeviceStressSummary) -> String {
        [
            "VeilLink Device Burn-In / Stress Report",
            "Session: \(summary.sessionID)",
            "Preset: \(summary.preset.rawValue)",
            "Started: \(ISO8601DateFormatter().string(from: summary.startedAt))",
            "Finished: \(ISO8601DateFormatter().string(from: summary.finishedAt))",
            "Stop reason: \(summary.stopReason)",
            "Cycles: \(summary.completedCycles)",
            "Steps: \(summary.completedSteps)",
            "Passed: \(summary.passedSteps)",
            "Skipped: \(summary.skippedSteps)",
            "Failed: \(summary.failedSteps)",
            "Memory warnings: \(summary.memoryWarnings)",
            "Elapsed ms: \(summary.elapsedMilliseconds)",
            "Final thermal: \(summary.finalThermalState)",
            "Final battery: \(summary.finalBatteryLevel)",
            "",
            "Interpret with runtime.jsonl + stress-steps.json + MetricKit auxiliary payloads.",
            "No destructive chat/identity/trust mutations are intentionally performed by the burn-in harness."
        ].joined(separator: "\n")
    }

    private static func thermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private static func batteryLevelText() -> String {
        let level = UIDevice.current.batteryLevel
        return level < 0 ? "unknown" : String(format: "%.3f", level)
    }
}

private struct StressFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
