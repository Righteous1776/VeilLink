import Combine
import Foundation
import UIKit

@MainActor
final class RuntimeDiagnosticsBridge {
    static let shared = RuntimeDiagnosticsBridge()

    private let store = DiagnosticLogStore.shared
    private var cancellables = Set<AnyCancellable>()
    private weak var attachedModel: AppModel?
    private var previousLinkFingerprints: [UUID: String] = [:]

    private init() {}

    func attach(to model: AppModel) {
        DeepTelemetry.shared.install()
        guard attachedModel !== model else { return }
        attachedModel = model
        cancellables.removeAll()

        recordModelSnapshot(model, reason: "bridge.attach")

        model.$selectedSection
            .removeDuplicates()
            .sink { section in
                Task { @MainActor in
                    DeepTelemetry.shared.setNavigationScreen(
                        Self.screenName(section: section, conversationID: model.selectedConversation?.id),
                        metadata: ["section": section.rawValue]
                    )
                }
            }
            .store(in: &cancellables)

        model.$selectedConversation
            .map { $0?.id ?? "none" }
            .removeDuplicates()
            .sink { conversationID in
                Task { @MainActor in
                    let screen = Self.screenName(section: model.selectedSection, conversationID: conversationID == "none" ? nil : conversationID)
                    DeepTelemetry.shared.setNavigationScreen(
                        screen,
                        metadata: ["conversation_id": conversationID]
                    )
                }
            }
            .store(in: &cancellables)

        model.$messagesRevision
            .removeDuplicates()
            .sink { revision in
                Task { @MainActor in
                    self.store.log(
                        .debug,
                        .ui,
                        event: "ui.messages_revision",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: ["revision": String(revision)]
                    )
                }
            }
            .store(in: &cancellables)

        model.bluetooth.$isRunning
            .removeDuplicates()
            .sink { running in
                Task { @MainActor in
                    self.store.log(.info, .bluetooth, event: "ble.running", screen: DeepTelemetry.shared.currentScreen, metadata: ["running": String(running)])
                }
            }
            .store(in: &cancellables)

        model.bluetooth.$statusText
            .removeDuplicates()
            .sink { status in
                Task { @MainActor in
                    self.store.log(.info, .bluetooth, event: "ble.status", screen: DeepTelemetry.shared.currentScreen, message: status)
                }
            }
            .store(in: &cancellables)

        model.bluetooth.$connectedPeerCount
            .removeDuplicates()
            .sink { count in
                Task { @MainActor in
                    self.store.log(.info, .bluetooth, event: "ble.connected_peer_count", screen: DeepTelemetry.shared.currentScreen, metadata: ["count": String(count)])
                }
            }
            .store(in: &cancellables)

        model.bluetooth.$linkSnapshots
            .throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)
            .sink { snapshots in
                Task { @MainActor in self.recordLinkSnapshots(snapshots) }
            }
            .store(in: &cancellables)

        model.sessions.$nearbyPeers
            .throttle(for: .milliseconds(750), scheduler: RunLoop.main, latest: true)
            .sink { peers in
                Task { @MainActor in
                    self.store.log(
                        .debug,
                        .session,
                        event: "session.nearby_peers",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "count": String(peers.count),
                            "peers": peers.prefix(32).map {
                                let secureReady = model.sessions.hasSecureSession(for: $0.id)
                                return "\($0.transportID.uuidString):\($0.id):\($0.rssi):\(String(describing: $0.trustState)):secure=\(secureReady)"
                            }.joined(separator: "|")
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.sessions.$lastError
            .compactMap { $0 }
            .removeDuplicates()
            .sink { error in
                Task { @MainActor in
                    self.store.log(.error, .session, event: "session.error", screen: DeepTelemetry.shared.currentScreen, message: error)
                }
            }
            .store(in: &cancellables)

        model.sessions.$securityEvents
            .sink { events in
                Task { @MainActor in
                    guard let latest = events.first else { return }
                    self.store.log(
                        .warning,
                        .security,
                        event: "security.event",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "count": String(events.count),
                            "length": String(latest.count),
                            "fingerprint": Self.stableFingerprint(latest)
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.a9Health.$decision
            .sink { decision in
                Task { @MainActor in
                    self.store.log(
                        decision.light == .red ? .warning : .debug,
                        .a9,
                        event: "a9.decision",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "light": decision.light.title,
                            "level": decision.level.shortTitle,
                            "health": String(decision.healthScore),
                            "risk": String(format: "%.2f", decision.riskPoints),
                            "persistence_seconds": String(decision.persistenceSeconds),
                            "transport_coverage": model.a9Health.transportCoverage.rawValue,
                            "reason": decision.reasonCode,
                            "cell": String(decision.latticeIndex),
                            "issues": String(decision.issues.count)
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.latticeKernel.$snapshot
            .removeDuplicates()
            .sink { snapshot in
                Task { @MainActor in
                    self.store.log(
                        snapshot.unexpectedDecisionDiffs > 0 ? .warning : .info,
                        .a9,
                        event: "kernel.integration_state",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "stage": snapshot.stage.rawValue,
                            "active_profile": snapshot.activeProfileID,
                            "candidate_profile": snapshot.candidateProfileID ?? "none",
                            "authority": snapshot.authority.rawValue,
                            "signal_bus": String(snapshot.signalBusVersion),
                            "unexpected_diffs": String(snapshot.unexpectedDecisionDiffs),
                            "compute_mode": snapshot.computeMode ?? "none"
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.kernelRuntime.$mode
            .sink { _ in
                Task { @MainActor in
                    let env = model.kernelRuntime.snapshot()
                    self.store.log(
                        env.mode.isExperimental ? .warning : .info,
                        .a9,
                        event: "kernel.runtime_mode",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "kernel_mode": env.mode.rawValue,
                            "mode_epoch": String(env.modeEpoch),
                            "mode_session_id": env.modeSessionID,
                            "selection_source": env.selectionSource,
                            "production_authority": env.productionAuthority,
                            "fallback_policy": env.fallbackPolicy,
                            "a9_enabled": String(env.a9EvaluationEnabled),
                            "ultra_enabled": String(env.ultraEvaluationEnabled),
                            "mutation_authority": String(env.mutationAuthority),
                            "production_cutover": env.productionCutover,
                            "last_fallback_reason": model.kernelRuntime.lastFallbackReason ?? "none"
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.a10Ultra.$lastRuntimeSample
            .compactMap { $0 }
            .sink { record in
                Task { @MainActor in
                    let env = record.environment
                    self.store.log(
                        record.fallbackEvent ? .warning : .debug,
                        .a9,
                        event: "kernel.runtime_sample",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "kernel_mode": env.mode.rawValue,
                            "mode_epoch": String(env.modeEpoch),
                            "mode_session_id": env.modeSessionID,
                            "mode_sample_ordinal": String(env.modeSampleOrdinal),
                            "mode_elapsed_ms": String(max(0, Int(record.timestamp.timeIntervalSince(env.enteredAt) * 1_000))),
                            "selection_source": env.selectionSource,
                            "production_authority": env.productionAuthority,
                            "fallback_policy": env.fallbackPolicy,
                            "a9_enabled": String(env.a9EvaluationEnabled),
                            "ultra_enabled": String(env.ultraEvaluationEnabled),
                            "mutation_authority": String(env.mutationAuthority),
                            "production_cutover": env.productionCutover,
                            "device_profile": VeilDevicePerformance.diagnosticLabel,
                            "render_profile": VeilRenderProfile.diagnosticLabel,
                            "foreground_active": String(model.computeGovernor.foregroundActive),
                            "compute_focus": model.computeGovernor.focus.rawValue,
                            "a9_plan_frozen": String(model.computeGovernor.planFrozen),
                            "sample_id": record.sampleID,
                            "epoch": String(record.epoch),
                            "timestamp": ISO8601DateFormatter().string(from: record.timestamp),
                            "source_domain": record.sourceDomains.joined(separator: ","),
                            "signal_digest": record.signalDigest,
                            "signal_provenance": "RAW_HOST_PRE_DECISION",
                            "a9_light": record.a9Decision?.light ?? "disabled",
                            "a9_level": record.a9Decision.map { String($0.level) } ?? "disabled",
                            "a9_risk_bp": record.a9Decision.map { String($0.riskBasisPoints) } ?? "disabled",
                            "a9_budget": record.a9Budget?.mode ?? "disabled",
                            "ultra_light": record.ultraDecision?.light ?? "disabled",
                            "ultra_level": record.ultraDecision.map { String($0.level) } ?? "disabled",
                            "ultra_risk_bp": record.ultraDecision.map { String($0.riskBasisPoints) } ?? "disabled",
                            "ultra_budget": record.ultraBudget?.mode ?? "disabled",
                            "decision_match": record.decisionMatch.map { String($0) } ?? "not_comparable",
                            "divergence_class": record.divergenceClass,
                            "a9_latency_us": String(record.a9LatencyNanos / 1_000),
                            "ultra_latency_us": String(record.ultraLatencyNanos / 1_000),
                            "a9_cpu_us": String(record.a9CPUNanos / 1_000),
                            "ultra_cpu_us": String(record.ultraCPUNanos / 1_000),
                            "combined_cpu_us": String((record.a9CPUNanos &+ record.ultraCPUNanos) / 1_000),
                            "ultra_physical_slot_count": String(record.ultraPhysicalSlotCount),
                            "rss_bytes": String(record.rssBytes),
                            "thermal_state": String(record.thermalState),
                            "battery_permille": String(record.batteryPermille),
                            "energy_proxy": String(record.energyProxy),
                            "energy_proxy_scope": env.mode == .dualShadow ? "COMBINED_A9_ULTRA" : "ACTIVE_RAIL_ONLY",
                            "ble_state": record.bleState,
                            "queue_depth": String(record.queueDepth),
                            "dropped_event_count": String(record.droppedEventCount),
                            "ultra_restart_count": String(record.ultraRestartCount),
                            "fallback_event": String(record.fallbackEvent),
                            "guardian_status": record.guardianStatus,
                            "rage_status": record.rageStatus,
                            "vault_status": record.vaultStatus,
                            "runtime_backend": record.runtimeBackend
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.maleCNS.$state
            .sink { state in
                Task { @MainActor in
                    let level: DiagnosticLogLevel
                    if case .failed = state { level = .error } else { level = .info }
                    self.store.log(level, .agent, event: "malecns.state", screen: DeepTelemetry.shared.currentScreen, message: state.displayName)
                }
            }
            .store(in: &cancellables)

        model.agent.$threeCoreSnapshot
            .removeDuplicates()
            .sink { snapshot in
                Task { @MainActor in
                    self.store.log(
                        snapshot.phase == .fallback ? .warning : .info,
                        .agent,
                        event: "agent.three_core_state",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "phase": snapshot.phase.rawValue,
                            "a9_role": snapshot.a9Role.rawValue,
                            "a10_role": snapshot.a10Role.rawValue,
                            "ling_core_role": snapshot.lingCoreRole.rawValue,
                            "a10_runtime_id": snapshot.a10RuntimeID ?? "EMPTY_READY",
                            "a10_runtime_state": snapshot.a10RuntimeState,
                            "language_backend": snapshot.languageBackend,
                            "a9_budget_mode": snapshot.a9BudgetMode,
                            "mutation_authority": snapshot.mutationAuthorityOwner,
                            "legacy_shadow": snapshot.legacyGovernanceShadow,
                            "fallback_reason": snapshot.fallbackReason ?? "none"
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.agent.$a10M5ShadowCognition
            .removeDuplicates()
            .sink { snapshot in
                guard snapshot.result != "IDLE" else { return }
                Task { @MainActor in
                    self.store.log(
                        snapshot.result == "FAILED" ? .warning : .debug,
                        .agent,
                        event: "a10.m5.cognition_shadow",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "result": snapshot.result,
                            "runtime_id": snapshot.runtimeID,
                            "output_digest": snapshot.outputDigest,
                            "estimated_tokens": String(snapshot.estimatedTokenCount),
                            "latency_ms": String(snapshot.latencyMilliseconds),
                            "mutation_authority": "0",
                            "prompt_logged": "false",
                            "output_text_logged": "false",
                            "failure": snapshot.failure ?? "none"
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.a10M5Governance.$snapshot
            .removeDuplicates()
            .sink { snapshot in
                guard snapshot.evaluatedAt != .distantPast else { return }
                Task { @MainActor in
                    self.store.log(
                        .debug,
                        .a9,
                        event: "a10.m5.governance_shadow",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "states": snapshot.states.joined(separator: ","),
                            "action_proposals": snapshot.actionProposals.joined(separator: ","),
                            "output_digest": snapshot.outputDigest,
                            "latency_us": String(snapshot.latencyNanoseconds / 1_000),
                            "backend": snapshot.backend,
                            "model_hash": snapshot.modelHash,
                            "feature_adapter": snapshot.featureAdapter,
                            "recommendation": snapshot.recommendation,
                            "mutation_authority": "0",
                            "user_plaintext_logged": "false"
                        ]
                    )
                }
            }
            .store(in: &cancellables)

        model.agent.$runtimeState
            .map { String(describing: $0) }
            .removeDuplicates()
            .sink { state in
                Task { @MainActor in
                    self.store.log(.info, .agent, event: "agent.runtime", screen: DeepTelemetry.shared.currentScreen, message: state)
                }
            }
            .store(in: &cancellables)

        model.agent.$diagnostics
            .map { diagnostics in diagnostics.lastFailure ?? "ok" }
            .removeDuplicates()
            .sink { state in
                Task { @MainActor in
                    let level: DiagnosticLogLevel = state == "ok" ? .debug : .error
                    self.store.log(level, .agent, event: "agent.diagnostics", screen: DeepTelemetry.shared.currentScreen, message: state)
                }
            }
            .store(in: &cancellables)

        model.ownerMode.$isUnlocked
            .removeDuplicates()
            .sink { unlocked in
                Task { @MainActor in DeepTelemetry.shared.recordOwnerAccess(unlocked: unlocked) }
            }
            .store(in: &cancellables)

        model.appLock.$isLocked
            .removeDuplicates()
            .sink { locked in
                Task { @MainActor in
                    self.store.log(.info, .security, event: locked ? "app_lock.locked" : "app_lock.unlocked", screen: DeepTelemetry.shared.currentScreen)
                }
            }
            .store(in: &cancellables)

        model.appLock.$failedAttempts
            .removeDuplicates()
            .sink { attempts in
                Task { @MainActor in
                    guard attempts > 0 else { return }
                    self.store.log(.warning, .security, event: "app_lock.failed_attempt", screen: DeepTelemetry.shared.currentScreen, metadata: ["attempts": String(attempts)])
                }
            }
            .store(in: &cancellables)

        model.$alertMessage
            .compactMap { $0 }
            .sink { alert in
                Task { @MainActor in
                    self.store.log(
                        .warning,
                        .ui,
                        event: "ui.alert.present",
                        screen: DeepTelemetry.shared.currentScreen,
                        metadata: [
                            "length": String(alert.count),
                            "fingerprint": Self.stableFingerprint(alert)
                        ]
                    )
                    DeepTelemetry.shared.captureUIHierarchy(reason: "alert", force: true)
                }
            }
            .store(in: &cancellables)
    }

    func recordStartupBegin() {
        store.log(.info, .app, event: "startup.begin", metadata: ["build": VeilBuildInfo.display])
    }

    func recordStartupSuccess() {
        store.log(.info, .app, event: "startup.success")
        DeepTelemetry.shared.captureSystemSnapshot(reason: "startup.success")
    }

    func recordStartupFailure(_ error: Error) {
        store.log(.critical, .app, event: "startup.failure", message: error.localizedDescription)
    }

    func recordLifecycle(_ state: String) {
        store.log(.info, .app, event: "lifecycle.\(state)", screen: DeepTelemetry.shared.currentScreen)
        DeepTelemetry.shared.install()
        DeepTelemetry.shared.captureSystemSnapshot(reason: "lifecycle.\(state)")
    }

    func recordMemoryPressure() {
        store.log(.warning, .performance, event: "memory.warning", screen: DeepTelemetry.shared.currentScreen)
        DeepTelemetry.shared.captureSystemSnapshot(reason: "memory.warning")
    }

    func recordSemanticAction(_ action: String, metadata: [String: String] = [:]) {
        DeepTelemetry.shared.action(action, metadata: metadata)
    }

    func captureIncidentSnapshot(for model: AppModel, reason: String) {
        recordModelSnapshot(model, reason: reason)
        DeepTelemetry.shared.captureSystemSnapshot(reason: reason, extra: [
            "device_id": model.identity.deviceID,
            "active_identity_id": model.identity.activeIdentity?.id ?? "none"
        ])
        DeepTelemetry.shared.captureUIHierarchy(reason: reason, force: true)
    }

    func exportBundle(for model: AppModel) throws -> URL {
        try exportBundle(for: model, reason: "diagnostics.export", extraFiles: [:])
    }

    func exportBundle(
        for model: AppModel,
        reason: String,
        extraFiles: [String: Data]
    ) throws -> URL {
        captureIncidentSnapshot(for: model, reason: reason)

        let context = makeRuntimeContext(model)
        let uiState = makeUIStateJSON(model)
        let deviceState = makeDeviceStateJSON(model)
        var files: [String: Data] = [
            "ui-state.json": uiState,
            "device-state.json": deviceState
        ]
        for (name, data) in extraFiles {
            files[name] = data
        }
        let url = try store.exportBundle(context: context, extraFiles: files)
        store.log(
            .info,
            .app,
            event: "diagnostics.export",
            screen: DeepTelemetry.shared.currentScreen,
            metadata: [
                "files": String(store.exportedFileCount),
                "reason": reason,
                "extra_files": String(extraFiles.count)
            ]
        )
        return url
    }

    private func recordLinkSnapshots(_ snapshots: [UUID: BLEPeerLinkSnapshot]) {
        var liveIDs = Set<UUID>()
        for (id, snapshot) in snapshots {
            liveIDs.insert(id)
            let fingerprint = [
                String(snapshot.isConnected),
                String(snapshot.isRecovering),
                String(snapshot.healthScore),
                String(snapshot.pendingBytes),
                String(snapshot.controlPendingPackets),
                String(snapshot.reconnectAttempt),
                snapshot.transportStage.rawValue,
                snapshot.queueSummary,
                snapshot.compactDetail
            ].joined(separator: "|")
            guard previousLinkFingerprints[id] != fingerprint else { continue }
            previousLinkFingerprints[id] = fingerprint
            store.log(
                snapshot.healthScore < 40 ? .warning : .debug,
                .bluetooth,
                event: "ble.link_snapshot",
                screen: DeepTelemetry.shared.currentScreen,
                metadata: [
                    "transport_id": id.uuidString,
                    "connected": String(snapshot.isConnected),
                    "recovering": String(snapshot.isRecovering),
                    "transport_stage": snapshot.transportStage.rawValue,
                    "status": snapshot.statusTitle,
                    "quality": String(describing: snapshot.quality),
                    "health": String(snapshot.healthScore),
                    "pending_bytes": String(snapshot.pendingBytes),
                    "control_pending_packets": String(snapshot.controlPendingPackets),
                    "reconnect_attempt": String(snapshot.reconnectAttempt),
                    "stalled_ms": String(Int((snapshot.stalledFor ?? 0) * 1_000)),
                    "queue": snapshot.queueSummary,
                    "detail": snapshot.compactDetail
                ]
            )
        }
        for id in previousLinkFingerprints.keys where !liveIDs.contains(id) {
            previousLinkFingerprints.removeValue(forKey: id)
            store.log(.debug, .bluetooth, event: "ble.link_removed", metadata: ["transport_id": id.uuidString])
        }
    }

    private func recordModelSnapshot(_ model: AppModel, reason: String) {
        store.log(
            .info,
            .app,
            event: "app.model_snapshot",
            screen: DeepTelemetry.shared.currentScreen,
            metadata: [
                "reason": reason,
                "device_id": model.identity.deviceID,
                "active_identity_id": model.identity.activeIdentity?.id ?? "none",
                "primary_identity_id": model.identity.primaryIdentity?.id ?? "none",
                "identity_count": String(model.identity.profiles.count),
                "selected_section": model.selectedSection.rawValue,
                "selected_conversation_id": model.selectedConversation?.id ?? "none",
                "conversation_count": String(model.conversations.count),
                "total_unread": String(model.totalUnreadCount),
                "ble_running": String(model.bluetooth.isRunning),
                "connected_peers": String(model.bluetooth.connectedPeerCount),
                "tracked_links": String(model.bluetooth.linkSnapshots.count),
                "nearby_peers": String(model.sessions.nearbyPeers.count),
                "owner_unlocked": String(model.ownerMode.isUnlocked),
                "render_profile": VeilRenderProfile.diagnosticLabel,
                "device_profile": VeilDevicePerformance.diagnosticLabel
            ]
        )
    }

    private func makeRuntimeContext(_ model: AppModel) -> String {
        var lines = [
            "VeilLink Deep Telemetry Runtime Context",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "Build: \(VeilBuildInfo.display)",
            "Runtime session: \(store.runtimeSessionID)",
            "Current UI screen: \(DeepTelemetry.shared.currentScreen)",
            "Device ID: \(model.identity.deviceID)",
            "IDFV: \(UIDevice.current.identifierForVendor?.uuidString ?? "unavailable")",
            "Active identity ID: \(model.identity.activeIdentity?.id ?? "none")",
            "Primary identity ID: \(model.identity.primaryIdentity?.id ?? "none")",
            "Selected section: \(model.selectedSection.rawValue)",
            "Selected conversation ID: \(model.selectedConversation?.id ?? "none")",
            "Conversations: \(model.conversations.count)",
            "Unread: \(model.totalUnreadCount)",
            "Owner unlocked: \(model.ownerMode.isUnlocked)",
            "Render: \(VeilRenderProfile.diagnosticLabel)",
            "Device profile: \(VeilDevicePerformance.diagnosticLabel)",
            "",
            model.bluetooth.diagnosticsReport(),
            "",
            model.a9DiagnosticsReport(),
            "",
            model.agent.diagnosticsReport(),
            "",
            "MaleCNS: core-disabled (history preserved)"
        ]
        if let identity = model.identity.activeIdentity {
            lines.append("Pending outbound: \(model.database.pendingOutboundCount(localIdentityID: identity.id))")
        }
        return lines.joined(separator: "\n")
    }

    private func makeUIStateJSON(_ model: AppModel) -> Data {
        let object: [String: Any] = [
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "current_screen": DeepTelemetry.shared.currentScreen,
            "selected_section": model.selectedSection.rawValue,
            "selected_conversation_id": model.selectedConversation?.id ?? NSNull(),
            "conversation_count": model.conversations.count,
            "unread_count": model.totalUnreadCount,
            "owner_unlocked": model.ownerMode.isUnlocked,
            "raw_touch_capture": DeepTelemetry.shared.rawTouchCaptureEnabled,
            "input_lifecycle_capture": DeepTelemetry.shared.inputLifecycleCaptureEnabled,
            "post_interaction_snapshots": DeepTelemetry.shared.postInteractionSnapshotsEnabled,
            "performance_watch": DeepTelemetry.shared.performanceWatchEnabled
        ]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    private func makeDeviceStateJSON(_ model: AppModel) -> Data {
        let object: [String: Any] = [
            "generated_at": ISO8601DateFormatter().string(from: Date()),
            "device_id": model.identity.deviceID,
            "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "unavailable",
            "system_name": UIDevice.current.systemName,
            "system_version": UIDevice.current.systemVersion,
            "model": UIDevice.current.model,
            "render_profile": VeilRenderProfile.diagnosticLabel,
            "device_profile": VeilDevicePerformance.diagnosticLabel,
            "physical_memory": ProcessInfo.processInfo.physicalMemory,
            "processor_count": ProcessInfo.processInfo.processorCount,
            "active_processor_count": ProcessInfo.processInfo.activeProcessorCount,
            "low_power": ProcessInfo.processInfo.isLowPowerModeEnabled
        ]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    private static func screenName(section: SidebarSection, conversationID: String?) -> String {
        switch section {
        case .chats:
            return conversationID == nil ? "chats.list" : "chats.detail"
        case .nearby: return "nearby"
        case .games: return "games.lobby"
        case .agent: return "agent.home"
        case .settings: return "settings"
        }
    }

    private static func stableFingerprint(_ text: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }
}
