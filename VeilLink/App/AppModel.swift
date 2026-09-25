import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var selectedConversation: ConversationSummary?
    @Published var selectedSection: SidebarSection = .chats
    @Published var exportedBackupURL: URL?
    @Published var exportedDiagnosticsURL: URL?
    @Published private(set) var autoRegulationSummary = "尚未评估"
    @Published private(set) var autoRegulationLastActionAt: Date?
    private var autoRegulationLastEvaluationAt: Date?
    private var autoRegulationLastMaintenanceAt: Date?
    private var autoRegulationLastBLERepairAt: Date?
    private var autoRegulationLastLoggedFingerprint: String?
    private var autoRegulationManualHoldUntil: Date?
    private var autoRegulationApplying = false
    @Published var alertMessage: String?
    @Published private(set) var messagesRevision = 0
    @Published private(set) var activeConversationID: String?
    @Published private(set) var performanceRevision = 0
    @Published var autoSaveReceivedImages: Bool {
        didSet { UserDefaults.standard.set(autoSaveReceivedImages, forKey: Self.autoSaveReceivedImagesKey) }
    }
    private var messageRefreshTask: Task<Void, Never>?
    private var a9RefreshTask: Task<Void, Never>?
    private var a9PeriodicTask: Task<Void, Never>?
    private var a9Cancellables = Set<AnyCancellable>()
    private var pendingConversationRefresh = false
    private static let autoSaveReceivedImagesKey = "media.autoSaveReceivedImages"

    let keychain: KeychainStore
    let database: DatabaseStore
    let identity: IdentityManager
    let appLock: AppLockController
    let ownerMode: OwnerModeController
    let bluetooth: BLETransport
    let sessions: SessionCoordinator
    let backups: BackupManager
    let haptics: HapticEngine
    let performanceOverrides: PerformanceOverrideController
    let a9Health: VeilA9HealthMonitor
    let computeGovernor: VeilA9ComputeGovernor
    let agentControls: AgentControlCenterSettings
    let gameIntelligence: AgentGameContextBroker
    let agent: AgentCoordinator

    var totalUnreadCount: Int {
        conversations.reduce(0) { partial, conversation in
            min(999, partial + conversation.unreadCount)
        }
    }

    init() throws {
        autoSaveReceivedImages = UserDefaults.standard.bool(forKey: Self.autoSaveReceivedImagesKey)
        let keychain = KeychainStore()
        self.keychain = keychain
        database = try DatabaseStore(keychain: keychain)
        identity = IdentityManager(keychain: keychain)
        for profile in identity.profiles { try? database.upsertProfile(profile) }
        if identity.profiles.count == 1, let onlyIdentity = identity.profiles.first {
            try? database.adoptLegacyUnscopedRows(localIdentityID: onlyIdentity.id)
        }
        appLock = AppLockController(keychain: keychain)
        ownerMode = OwnerModeController()
        performanceOverrides = PerformanceOverrideController()
        bluetooth = BLETransport()
        sessions = SessionCoordinator(identity: identity, database: database)
        backups = BackupManager(database: database, identity: identity)
        haptics = HapticEngine()
        a9Health = VeilA9HealthMonitor()
        let agentProfile = AgentCapabilityProfile.current
        computeGovernor = VeilA9ComputeGovernor(profile: agentProfile)
        agentControls = AgentControlCenterSettings()
        computeGovernor.setExperimentalCoreEnabled(false)
        gameIntelligence = AgentGameContextBroker()
        agent = AgentCoordinator(
            runtime: LocalTextModelRuntimeFactory.make(profile: agentProfile),
            capabilityProfile: agentProfile,
            computeGovernor: computeGovernor
        )
        performanceOverrides.onChange = { [weak self] in
            self?.applyPerformanceOverrideChange()
        }

        bluetooth.onDiscovered = { [weak sessions] id, rssi in
            sessions?.discovered(transportID: id, rssi: rssi)
        }
        bluetooth.onConnected = { [weak sessions] id in
            sessions?.connected(transportID: id)
        }
        bluetooth.onDisconnected = { [weak sessions] id in
            sessions?.disconnected(transportID: id)
        }
        bluetooth.onReceive = { [weak sessions] id, data in sessions?.receive(transportID: id, data: data) }
        sessions.transportSend = { [weak bluetooth] id, data, priority in
            bluetooth?.send(data, to: id, priority: priority) ?? .temporarilyUnavailable
        }
        sessions.transportDisconnect = { [weak bluetooth] id in bluetooth?.disconnect(id) }
        sessions.onMessagesChanged = { [weak self] refreshConversations in
            self?.scheduleMessageRefresh(refreshConversations: refreshConversations)
        }
        sessions.onInboundMessageReceived = { [weak self] in
            self?.haptics.receive()
        }
        sessions.onDeliveryConfirmed = { [weak self] in
            self?.haptics.resolved()
        }
        sessions.onInboundAttachmentCompleted = { [weak self] messageID in
            guard let self, self.autoSaveReceivedImages else { return }
            Task { @MainActor [weak self] in await self?.autoSaveReceivedImage(messageID: messageID) }
        }
        agent.bindIntegration(
            localContextProvider: { [weak self] in self?.makeAgentLocalContext() },
            toolExecutor: { [weak self] text in self?.executeAgentTool(text) }
        )
        agent.setVisualContextEnabled(agentControls.visualContextEnabled)
        configureA9HealthMonitoring()
        reloadConversations()
        refreshA9Health()
        startA9PeriodicSampling()
    }

    private func applyPerformanceOverrideChange() {
        messageRefreshTask?.cancel()
        pendingConversationRefresh = false
        database.clearTransientCaches()
        sessions.clearTransientCaches()
        ImagePreviewCache.shared.removeAll()
        ImagePreviewCache.shared.reconfigureForCurrentProfile()
        performanceRevision &+= 1
    }

    private func configureA9HealthMonitoring() {
        bluetooth.$linkSnapshots
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        bluetooth.$isRunning
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        agent.$runtimeState
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        agent.$diagnostics
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleA9Refresh() }
            }
            .store(in: &a9Cancellables)
        a9Health.$decision
            .sink { [weak self] decision in
                Task { @MainActor [weak self] in self?.computeGovernor.update(decision: decision) }
            }
            .store(in: &a9Cancellables)
    }

    private func scheduleA9Refresh() {
        a9RefreshTask?.cancel()
        a9RefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshA9Health()
        }
    }

    func refreshA9Health() {
        let snapshots = Array(bluetooth.linkSnapshots.values)
        let input = VeilA9Input(
            bluetoothRunning: bluetooth.isRunning,
            connectedPeerCount: snapshots.filter(\.isConnected).count,
            trackedPeerCount: snapshots.count,
            recoveringPeerCount: snapshots.filter(\.isRecovering).count,
            weakPeerCount: snapshots.filter { $0.quality == .weak }.count,
            marginalPeerCount: snapshots.filter { $0.quality == .marginal }.count,
            minimumLinkHealth: snapshots.map(\.healthScore).min(),
            maximumReconnectAttempt: snapshots.map(\.reconnectAttempt).max() ?? 0,
            pendingBytes: snapshots.reduce(0) { $0 + $1.pendingBytes },
            controlPendingPackets: snapshots.reduce(0) { $0 + $1.controlPendingPackets },
            maximumStallMilliseconds: Int((snapshots.compactMap(\.stalledFor).max() ?? 0) * 1_000),
            agentUnavailable: agent.runtimeState == .unavailable,
            agentCooling: agent.runtimeState == .cooling,
            agentHasFailure: agent.diagnostics.lastFailure != nil,
            thermalLevel: currentA9ThermalLevel(),
            lowPowerMode: currentA9LowPowerMode(),
            databaseIntegrity: a9Health.databaseIntegrity
        )
        a9Health.evaluate(input)
    }

    func runA9StorageCheck() {
        let result = database.integrityCheck().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        a9Health.setDatabaseIntegrity(result == "ok" ? .ok : .failed)
        refreshA9Health()
    }

    func a9DiagnosticsReport() -> String {
        a9Health.report() + "\n\n" + computeGovernor.report()
    }

    private func currentA9ThermalLevel() -> VeilA9ThermalLevel {
        #if os(iOS)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
        #else
        return .nominal
        #endif
    }

    private func currentA9LowPowerMode() -> Bool {
        #if os(iOS)
        return ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        return false
        #endif
    }

    private func scheduleMessageRefresh(refreshConversations: Bool) {
        pendingConversationRefresh = pendingConversationRefresh || refreshConversations
        messageRefreshTask?.cancel()
        messageRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: VeilDevicePerformance.current.messageRefreshDebounceNanoseconds)
            guard !Task.isCancelled, let self else { return }
            let shouldRefreshConversations = self.pendingConversationRefresh
            self.pendingConversationRefresh = false

            if shouldRefreshConversations {
                if let activeConversationID = self.activeConversationID {
                    try? self.database.markConversationRead(conversationID: activeConversationID)
                }
                self.reloadConversations()
            }
            self.messagesRevision &+= 1
        }
    }


    private var a9PeriodicSamplingNanoseconds: UInt64 {
        switch agent.capabilityProfile.tier {
        case .legacyA10: return 8_000_000_000
        case .balanced: return 6_000_000_000
        case .high: return 4_000_000_000
        }
    }

    private func startA9PeriodicSampling() {
        guard a9PeriodicTask == nil else { return }
        a9PeriodicTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: a9PeriodicSamplingNanoseconds)
                guard !Task.isCancelled, let self else { break }
                self.refreshA9Health()
                self.evaluateAutoRegulation()
            }
        }
    }

    func handleForegroundTransition() {
        computeGovernor.setForegroundActive(true)
        refreshA9Health()
        startA9PeriodicSampling()
    }

    func handleMemoryPressure() {
        database.clearTransientCaches()
        sessions.clearTransientCaches()
        ImagePreviewCache.shared.removeAll()
        agent.handleMemoryPressure()
    }

    func handleBackgroundTransition() {
        computeGovernor.setForegroundActive(false)
        a9PeriodicTask?.cancel()
        a9PeriodicTask = nil
        agent.handleBackground()
        trimCachesForBackgroundIfNeeded()
    }

    func trimCachesForBackgroundIfNeeded() {
        guard VeilDevicePerformance.current.aggressiveBackgroundCacheTrim else { return }
        database.clearTransientCaches()
        sessions.clearTransientCaches()
        ImagePreviewCache.shared.removeAll()
    }

    func start() {
        guard identity.activeIdentity != nil else { return }
        _ = try? database.cleanupStaleInboundAttachments()
        bluetooth.start()
    }

    func createInitialProfile(name: String, password: String, pin: String) -> Bool {
        do {
            let profile = try identity.createProfile(displayName: name, password: password)
            try database.upsertProfile(profile)
            guard appLock.configure(pin: pin) else {
                alertMessage = appLock.errorMessage
                return false
            }
            start()
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func createAdditionalProfile(name: String, password: String) -> Bool {
        let wasRunning = bluetooth.isRunning
        bluetooth.stop()
        do {
            let profile = try identity.createProfile(displayName: name, password: password)
            try database.upsertProfile(profile)
            sessions.resetForIdentityChange()
            gameIntelligence.clear()
            selectedConversation = nil
            activeConversationID = nil
            reloadConversations()
            if wasRunning { bluetooth.start() }
            return true
        } catch {
            if wasRunning { bluetooth.start() }
            alertMessage = error.localizedDescription
            return false
        }
    }

    func switchIdentity(to id: String, password: String) -> Bool {
        guard identity.activeIdentity?.id != id else { return true }
        let wasRunning = bluetooth.isRunning
        bluetooth.stop()
        guard identity.switchProfile(to: id, password: password) else {
            if wasRunning { bluetooth.start() }
            alertMessage = "身份密码不正确。"
            return false
        }
        if let active = identity.activeIdentity { try? database.upsertProfile(active) }
        sessions.resetForIdentityChange()
        gameIntelligence.clear()
        selectedConversation = nil
        activeConversationID = nil
        reloadConversations()
        if wasRunning { bluetooth.start() }
        return true
    }

    func renameContact(peerIdentityID: String, displayName: String) -> Bool {
        guard let localIdentityID = identity.activeIdentity?.id else { return false }
        do {
            try database.renameContact(localIdentityID: localIdentityID, identityID: peerIdentityID, displayName: displayName)
            reloadConversations()
            messagesRevision &+= 1
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func deleteIdentity(id: String, password: String) -> Bool {
        guard identity.activeIdentity?.id != id else {
            alertMessage = IdentityError.cannotDeleteActiveIdentity.localizedDescription
            return false
        }
        guard identity.verifyPassword(password, for: id) else {
            alertMessage = "身份密码不正确。"
            return false
        }
        do {
            try database.deleteLocalIdentityData(localIdentityID: id)
            _ = try identity.deleteProfile(id: id, password: password)
            for profile in identity.profiles { try? database.upsertProfile(profile) }
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func deleteMessageLocally(messageID: String, conversationID: String) -> Bool {
        do {
            sessions.discardLocalMessage(messageID)
            try database.deleteMessageLocally(messageID: messageID, conversationID: conversationID)
            reloadConversations()
            messagesRevision &+= 1
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func clearConversationLocally(conversationID: String) -> Bool {
        let messageIDs = database.fetchMessageIDs(conversationID: conversationID)
        messageIDs.forEach { sessions.discardLocalMessage($0) }
        do {
            try database.clearConversationLocally(conversationID: conversationID)
            reloadConversations()
            messagesRevision &+= 1
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    private func autoSaveReceivedImage(messageID: String) async {
        guard autoSaveReceivedImages,
              let message = database.fetchMessage(id: messageID),
              !message.isOutgoing,
              let attachment = message.attachment,
              let data = database.loadAttachment(id: attachment.id) else { return }
        do {
            try await PhotoLibrarySaver.save(data: data, mimeType: attachment.mimeType)
        } catch {
            alertMessage = "自动保存收到的图片失败：\(error.localizedDescription)"
        }
    }

    func setTrust(for peerIdentityID: String, blocked: Bool) {
        guard let localIdentityID = identity.activeIdentity?.id else { return }
        do {
            try database.setPeerTrust(localIdentityID: localIdentityID, identityID: peerIdentityID, blocked: blocked)
            sessions.invalidatePeer(peerIdentityID)
            alertMessage = blocked ? "已拉黑该身份。历史记录仍保留。" : "已取消信任。重新通信前需要再次核对六码。"
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func reloadConversations() {
        guard let localIdentityID = identity.activeIdentity?.id else {
            conversations = []
            selectedConversation = nil
            activeConversationID = nil
            return
        }
        conversations = database.fetchConversations(localIdentityID: localIdentityID)
        if let selectedID = selectedConversation?.id {
            selectedConversation = conversations.first(where: { $0.id == selectedID })
        }
    }


    func setConversationVisible(_ conversationID: String, visible: Bool) {
        if visible {
            activeConversationID = conversationID
            do {
                try database.markConversationRead(conversationID: conversationID)
                reloadConversations()
            } catch {
                alertMessage = error.localizedDescription
            }
        } else if activeConversationID == conversationID {
            activeConversationID = nil
        }
    }

    func setConversationPinned(_ conversationID: String, pinned: Bool) -> Bool {
        do {
            try database.setConversationPinned(conversationID: conversationID, pinned: pinned)
            reloadConversations()
            haptics.selection()
            return true
        } catch {
            alertMessage = error.localizedDescription
            haptics.error()
            return false
        }
    }

    func markConversationRead(_ conversationID: String) -> Bool {
        do {
            try database.markConversationRead(conversationID: conversationID)
            reloadConversations()
            haptics.selection()
            return true
        } catch {
            alertMessage = error.localizedDescription
            haptics.error()
            return false
        }
    }

    func markConversationUnread(_ conversationID: String) -> Bool {
        do {
            try database.markConversationUnread(conversationID: conversationID)
            reloadConversations()
            haptics.selection()
            return true
        } catch {
            alertMessage = error.localizedDescription
            haptics.error()
            return false
        }
    }

    func exportBackup(password: String) {
        do {
            exportedBackupURL = try backups.exportBackup(password: password)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func restoreBackup(url: URL, password: String) {
        let accessed = url.startAccessingSecurityScopedResource()
        let wasRunning = bluetooth.isRunning
        bluetooth.stop()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
            if wasRunning || identity.activeIdentity != nil { start() }
        }
        do {
            try backups.restoreBackup(from: url, password: password)
            sessions.resetForIdentityChange()
            gameIntelligence.clear()
            selectedConversation = nil
            activeConversationID = nil
            reloadConversations()
            alertMessage = "备份已恢复。"
        } catch {
            sessions.resetForIdentityChange()
            gameIntelligence.clear()
            alertMessage = error.localizedDescription
        }
    }

    func updateAgentGameContext(_ session: MiniGameSessionSnapshot, conversation: ConversationSummary) {
        gameIntelligence.update(
            session: session,
            conversationTitle: conversation.title,
            peerIdentityID: conversation.peerIdentityID
        )
    }

    @discardableResult
    func executeAgentSuggestedGameMove() -> String {
        guard agentControls.allowSuggestedGameMoveExecution else {
            return "AI 控制中心当前禁止执行建议着法。你仍可以查看分析或手动在棋盘操作。"
        }
        guard let tentative = gameIntelligence.currentSuggestedAction() else {
            return "当前没有足够新鲜、经过合法动作校验的推荐着法；请回到棋局刷新后再试。"
        }
        guard let localIdentityID = identity.activeIdentity?.id,
              let conversationID = database.conversationID(
                localIdentityID: localIdentityID,
                for: tentative.peerIdentityID
              ),
              let latestSession = MiniGameSessionBuilder.session(
                id: tentative.sessionID,
                from: database.fetchMessages(conversationID: conversationID)
              ),
              let action = gameIntelligence.currentSuggestedAction(validating: latestSession),
              action == tentative else {
            return "棋局已经变化，这条 AI 建议已失效；请回到棋局刷新后重新获取建议。"
        }
        guard let game = MiniGameKind(rawValue: action.gameID) else {
            return "当前推荐动作的游戏类型无效。"
        }
        let packet = MiniGamePacket(
            sessionID: action.sessionID,
            game: game,
            command: .move,
            turn: action.turn,
            move: action.move
        )
        do {
            try sessions.sendMiniGamePacket(packet, to: action.peerIdentityID)
            gameIntelligence.markSuggestedActionExecuted(action)
            haptics.send()
            return "已执行刚刚重新通过原游戏引擎校验的建议着法：\(action.label)。动作仍通过当前 E2EE 游戏消息链路发送。"
        } catch {
            haptics.error()
            return "建议着法未执行：\(error.localizedDescription)"
        }
    }

    private func makeAgentLocalContext() -> AgentLocalContext {
        let snapshots = Array(bluetooth.linkSnapshots.values)
        let selectedContext: AgentConversationContext? = selectedConversation.map { conversation in
            let transportID = sessions.transportID(for: conversation.peerIdentityID)
            let link = transportID.flatMap { bluetooth.linkSnapshots[$0] ?? bluetooth.linkSnapshot(for: $0) }
            return AgentConversationContext(
                title: conversation.title,
                unreadCount: conversation.unreadCount,
                secureSessionReady: sessions.hasSecureSession(for: conversation.peerIdentityID),
                linkHealth: link?.healthScore,
                linkQuality: link?.qualityTitle
            )
        }
        return AgentLocalContext(
            generatedAt: Date(),
            activeIdentityName: identity.activeIdentity?.displayName,
            selectedConversation: selectedContext,
            bluetooth: AgentBluetoothContext(
                running: bluetooth.isRunning,
                trackedPeers: snapshots.count,
                connectedPeers: snapshots.filter(\.isConnected).count,
                recoveringPeers: snapshots.filter(\.isRecovering).count,
                pendingBytes: snapshots.reduce(0) { $0 + $1.pendingBytes },
                weakestHealth: snapshots.map(\.healthScore).min()
            ),
            a9HealthScore: a9Health.decision.healthScore,
            a9Mode: computeGovernor.plan.mode.title,
            databaseIntegrity: a9Health.databaseIntegrity.title,
            maleCNSState: "core-disabled",
            game: gameIntelligence.context,
            availableTools: VeilAppControlParser.advertisedCommands
        )
    }

    private func executeAgentTool(_ raw: String) -> AgentToolExecution? {
        guard let command = VeilAppControlParser.parse(raw) else { return nil }
        let result = executeAppControl(command, source: .agentRequest)
        return AgentToolExecution(command: result.commandID, message: result.message)
    }

    @discardableResult
    func executeAppControl(_ command: VeilAppControlCommand) -> VeilAppControlResult {
        executeAppControl(command, source: .directUser)
    }

    @discardableResult
    func executeAppControl(_ command: VeilAppControlCommand, source: VeilAppControlSource) -> VeilAppControlResult {
        let permissions = VeilAppControlPermissions(
            localMutationsEnabled: agentControls.localToolMutationsEnabled,
            diagnosticsExportEnabled: agentControls.allowDiagnosticsExport,
            suggestedMoveExecutionEnabled: agentControls.allowSuggestedGameMoveExecution,
            autoRegulationMode: agentControls.autoRegulationMode
        )
        let decision = VeilAppControlPolicy.authorize(command, permissions: permissions, source: source)
        guard decision.allowed else {
            let result = VeilAppControlResult.denied(
                command,
                reason: decision.reason ?? "当前控制策略拒绝了该操作。"
            )
            logAppControl(command: command, result: result, access: decision.access)
            return result
        }

        let result: VeilAppControlResult
        switch command {
        case .controlHelp:
            result = VeilAppControlResult(
                commandID: command.id,
                success: true,
                didMutate: false,
                message: "Control Plane V3 已启用。除 V2 的全 App 状态与调度外，新增 AutoTune 自动诊断/安全自调节。自动执行仅允许资源焦点、缓存释放和 BLE 刷新三类可逆动作。"
            )

        case .overviewStatus:
            let snapshots = Array(bluetooth.linkSnapshots.values)
            let connected = snapshots.filter(\.isConnected).count
            let pendingBytes = snapshots.reduce(0) { $0 + $1.pendingBytes }
            result = VeilAppControlResult(
                commandID: command.id,
                success: true,
                didMutate: false,
                message: "VeilLink：页面 \(selectedSection.rawValue)，BLE \(bluetooth.isRunning ? "运行中" : "已停止")，连接 \(connected)/\(snapshots.count)，待发 \(ByteCountFormatter.string(fromByteCount: Int64(pendingBytes), countStyle: .file))，A9 \(a9Health.decision.healthScore)/100，数据库 \(a9Health.databaseIntegrity.title)，灵核 \(agent.runtimeState.displayName)。"
            )

        case .transportStatus:
            let snapshots = Array(bluetooth.linkSnapshots.values)
            let connected = snapshots.filter(\.isConnected).count
            let recovering = snapshots.filter(\.isRecovering).count
            let pendingBytes = snapshots.reduce(0) { $0 + $1.pendingBytes }
            let controlPending = snapshots.reduce(0) { $0 + $1.controlPendingPackets }
            let weakest = snapshots.map(\.healthScore).min()
            result = VeilAppControlResult(
                commandID: command.id,
                success: true,
                didMutate: false,
                message: "BLE 传输：\(bluetooth.statusText)，已连接 \(connected)，恢复中 \(recovering)，待发 \(ByteCountFormatter.string(fromByteCount: Int64(pendingBytes), countStyle: .file))，控制包积压 \(controlPending)，最弱链路 \(weakest.map { "\($0)/100" } ?? "--")。"
            )

        case .mediaStatus:
            let profile = VeilDevicePerformance.current
            result = VeilAppControlResult(
                commandID: command.id,
                success: true,
                didMutate: false,
                message: "媒体策略：目标图片约 \(ByteCountFormatter.string(fromByteCount: Int64(MediaTransferPolicy.targetImageBytes), countStyle: .file))，单图上限 \(ByteCountFormatter.string(fromByteCount: Int64(MediaTransferPolicy.maximumImageBytes), countStyle: .file))，预览最长边 \(profile.imagePreviewMaxPixelSize)px，发送附件缓存 \(ByteCountFormatter.string(fromByteCount: Int64(profile.outboundAttachmentCacheBytes), countStyle: .file))，收到图片自动保存 \(autoSaveReceivedImages ? "开" : "关")。"
            )

        case .performanceStatus:
            result = VeilAppControlResult(
                commandID: command.id,
                success: true,
                didMutate: false,
                message: "性能：\(VeilDevicePerformance.diagnosticLabel)，A9 \(computeGovernor.plan.mode.title)，焦点 \(computeGovernor.plan.focus.title)，手动性能覆盖 \(performanceOverrides.isEnabled ? "开启(风险项 \(performanceOverrides.riskCount))" : "关闭")。"
            )

        case .diagnosticsStatus:
            let store = DiagnosticLogStore.shared
            result = VeilAppControlResult(
                commandID: command.id,
                success: true,
                didMutate: false,
                message: "诊断：内存索引 \(store.recentEntries.count) 条，磁盘 \(store.diskUsageText)，保留上限 \(store.retentionText)。诊断导出 \(agentControls.allowDiagnosticsExport ? "已授权" : "未授权")。"
            )

        case .autoRegulationStatus:
            let hold = max(0, Int(autoRegulationManualHoldUntil?.timeIntervalSinceNow ?? 0))
            result = VeilAppControlResult(
                commandID: command.id,
                success: true,
                didMutate: false,
                message: "AutoTune：\(agentControls.autoRegulationMode.title)。最近判断：\(autoRegulationSummary)\(hold > 0 ? "；人工焦点保护剩余约 \(hold)s" : "")。"
            )

        case .refreshBLE:
            bluetooth.refreshLinks()
            refreshA9Health()
            let connected = bluetooth.linkSnapshots.values.filter(\.isConnected).count
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已刷新 VeilLink BLE 扫描、广播、连接恢复与 RSSI 采样。当前连接 \(connected) 台设备。")

        case .startBLE:
            guard identity.activeIdentity != nil else {
                result = VeilAppControlResult(commandID: command.id, success: false, didMutate: false, message: "当前没有活动身份，无法启动 VeilLink BLE 通信。")
                break
            }
            start()
            refreshA9Health()
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已启动 VeilLink 的 BLE 通信服务；没有修改 iOS 系统蓝牙开关。")

        case .stopBLE:
            bluetooth.stop()
            refreshA9Health()
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已停止 VeilLink 的 BLE 通信服务；没有修改系统蓝牙设置。")

        case .databaseIntegrity:
            runA9StorageCheck()
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "本地 SQLite 完整性检查已执行：\(a9Health.databaseIntegrity.title)。没有读取或回显聊天正文。")

        case .a9Status:
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: false, message: "A9：健康度 \(a9Health.decision.healthScore)/100，计算模式 \(computeGovernor.plan.mode.title)，焦点 \(computeGovernor.plan.focus.title)，数据库 \(a9Health.databaseIntegrity.title)。")

        case .agentStatus:
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: false, message: "灵核运行时：\(agent.runtimeManifest?.displayName ?? LocalTextModelRuntimeFactory.backendName)，状态 \(agent.runtimeState.displayName)；游戏引擎 Native Bot；Control Plane V3 / AutoTune \(agentControls.autoRegulationMode.title)。")

        case .gameStatus:
            if let game = gameIntelligence.context {
                result = VeilAppControlResult(commandID: command.id, success: true, didMutate: false, message: "当前对局：\(game.gameTitle)，第 \(game.turn) 回合，\(game.isLocalTurn ? "轮到你" : "等待对方")，策略模式 \(game.policyMode)。")
            } else {
                result = VeilAppControlResult(commandID: command.id, success: true, didMutate: false, message: "当前没有已接入灵核的活动对局。")
            }

        case .executeSuggestedGameMove:
            let message = executeAgentSuggestedGameMove()
            let executed = message.hasPrefix("已执行")
            result = VeilAppControlResult(commandID: command.id, success: executed, didMutate: executed, message: message)

        case .trimCaches:
            database.clearTransientCaches()
            sessions.clearTransientCaches()
            ImagePreviewCache.shared.removeAll()
            agent.trimRuntimeMemory()
            refreshA9Health()
            performanceRevision &+= 1
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已清理数据库/会话临时缓存、图片预览缓存，并压缩本地对话运行时内存。聊天记录和密钥没有删除。")

        case .restoreAutomaticPerformance:
            performanceOverrides.restoreAutomaticPolicy()
            agent.trimRuntimeMemory()
            ImagePreviewCache.shared.removeAll()
            computeGovernor.setFocus(.idle)
            refreshA9Health()
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已恢复 VeilLink 自动性能策略并回到自动调度。不会修改 iOS 系统低电量模式。")

        case .activateAgentRuntime:
            agent.activate()
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已请求启动本地灵核运行时。Core 默认 VeilTalk Lite，不需要模型权重。")

        case .unloadAgentRuntime:
            agent.unloadRuntime()
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已卸载本地对话运行时状态；聊天数据库、Experimental AI 历史文件和控制平面均未删除。")

        case .setVisualContext(let enabled):
            setAgentVisualContextEnabled(enabled)
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: enabled ? "已允许视觉摘要进入本地 Agent 上下文。" : "已关闭视觉摘要进入本地 Agent 上下文。")

        case .setAutoSaveReceivedImages(let enabled):
            autoSaveReceivedImages = enabled
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: enabled ? "已开启收到图片自动保存到相册。" : "已关闭收到图片自动保存到相册。")

        case .setResourceFocus(let focus):
            switch focus {
            case .automatic:
                computeGovernor.setFocus(.idle)
            case .communications:
                computeGovernor.setFocus(.mediaTransfer)
            case .agent:
                computeGovernor.setFocus(.languageChat)
                if source != .automaticRegulator, agentControls.autoLoadLanguageModel { agent.activate() }
            case .game:
                computeGovernor.setFocus(.gameDecision)
            }
            if source != .automaticRegulator {
                autoRegulationManualHoldUntil = Date().addingTimeInterval(90)
            }
            refreshA9Health()
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已切换为“\(focus.title)”临时资源焦点。\(source == .automaticRegulator ? "由 AutoTune 安全调度触发。" : "已进入 90 秒人工焦点保护。")")

        case .setAutoRegulationMode(let mode):
            agentControls.autoRegulationMode = mode
            if mode == .off {
                autoRegulationSummary = "自动调控已关闭。"
            }
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "AutoTune 已切换为“\(mode.title)”。安全自动模式只允许焦点调度、清理临时缓存和刷新 BLE。")

        case .runAutoRegulationOnce:
            let beforeMutation = autoRegulationLastActionAt
            let summary = evaluateAutoRegulation(force: true)
            let didMutate = autoRegulationLastActionAt != beforeMutation
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: didMutate, message: summary)

        case .exportDiagnostics:
            do {
                let url = try RuntimeDiagnosticsBridge.shared.exportBundle(for: self, reason: "agent.control.export", extraFiles: [:])
                exportedDiagnosticsURL = url
                selectedSection = .agent
                result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "诊断包已在本机生成，分享面板将打开。包内可能包含设备、App 与 BLE 链路技术标识；不会故意记录聊天正文、私钥/会话密钥、配对码或原始 AI 提示词。")
            } catch {
                result = VeilAppControlResult(commandID: command.id, success: false, didMutate: false, message: "诊断包生成失败：\(error.localizedDescription)")
            }

        case .navigate(let destination):
            switch destination {
            case .chats: selectedSection = .chats
            case .nearby: selectedSection = .nearby
            case .games: selectedSection = .games
            case .agent: selectedSection = .agent
            case .settings: selectedSection = .settings
            }
            result = VeilAppControlResult(commandID: command.id, success: true, didMutate: true, message: "已切换到“\(destination.title)”页面。")
        }

        logAppControl(command: command, result: result, access: decision.access, source: source)
        return result
    }

    private func logAppControl(
        command: VeilAppControlCommand,
        result: VeilAppControlResult,
        access: VeilAppControlAccess,
        source: VeilAppControlSource
    ) {
        DiagnosticLogStore.shared.log(
            result.success ? .info : .warning,
            .agent,
            event: source == .automaticRegulator ? "agent.autotune.execute" : "agent.control.execute",
            message: result.message,
            metadata: [
                "command": command.id,
                "access": access.rawValue,
                "source": source.rawValue,
                "success": result.success ? "true" : "false",
                "mutated": result.didMutate ? "true" : "false"
            ]
        )
    }

    @discardableResult
    func evaluateAutoRegulation(force: Bool = false) -> String {
        guard !autoRegulationApplying else { return autoRegulationSummary }
        let mode = agentControls.autoRegulationMode
        let now = Date()
        if !force, let last = autoRegulationLastEvaluationAt, now.timeIntervalSince(last) < 3.5 {
            return autoRegulationSummary
        }
        autoRegulationLastEvaluationAt = now

        let snapshots = Array(bluetooth.linkSnapshots.values)
        let snapshot = VeilAutoRegulationSnapshot(
            mode: mode,
            thermal: currentAutoThermalLevel(),
            lowPowerMode: currentA9LowPowerMode(),
            a9HealthScore: a9Health.decision.healthScore,
            pendingBytes: snapshots.reduce(0) { $0 + $1.pendingBytes },
            controlPendingPackets: snapshots.reduce(0) { $0 + $1.controlPendingPackets },
            maximumStallMilliseconds: Int((snapshots.compactMap(\.stalledFor).max() ?? 0) * 1_000),
            recoveringPeerCount: snapshots.filter(\.isRecovering).count,
            connectedPeerCount: snapshots.filter(\.isConnected).count,
            currentFocus: currentResourceFocus(),
            visibleDestination: currentControlDestination(),
            agentGenerating: agent.isGenerating,
            gameActive: gameIntelligence.hasCurrentGame,
            manualFocusHoldActive: (autoRegulationManualHoldUntil?.timeIntervalSince(now) ?? 0) > 0,
            secondsSinceLastMutation: autoRegulationLastActionAt.map { now.timeIntervalSince($0) },
            secondsSinceLastMaintenance: autoRegulationLastMaintenanceAt.map { now.timeIntervalSince($0) },
            secondsSinceLastBLERepair: autoRegulationLastBLERepairAt.map { now.timeIntervalSince($0) }
        )
        let plan = VeilAutoRegulationPolicy.evaluate(snapshot)
        autoRegulationSummary = plan.summary

        let actionIDs = plan.actions.map { $0.controlCommand.id }.joined(separator: ",")
        let logFingerprint = "\(mode.rawValue)|\(plan.severity.rawValue)|\(plan.summary)|\(actionIDs)"
        if autoRegulationLastLoggedFingerprint != logFingerprint {
            DiagnosticLogStore.shared.log(
                plan.severity == .protection ? .warning : .debug,
                .performance,
                event: "agent.autotune.evaluate",
                message: plan.summary,
                metadata: [
                    "mode": mode.rawValue,
                    "severity": plan.severity.rawValue,
                    "actions": actionIDs
                ]
            )
            autoRegulationLastLoggedFingerprint = logFingerprint
        }

        guard mode == .safeAutomatic, !plan.actions.isEmpty else { return plan.summary }
        autoRegulationApplying = true
        defer { autoRegulationApplying = false }
        var applied: [String] = []
        for action in plan.actions {
            let result = executeAppControl(action.controlCommand, source: .automaticRegulator)
            guard result.success else { continue }
            applied.append(result.commandID)
            autoRegulationLastActionAt = now
            switch action {
            case .trimCaches: autoRegulationLastMaintenanceAt = now
            case .refreshBLE: autoRegulationLastBLERepairAt = now
            case .setFocus: break
            }
        }
        if !applied.isEmpty {
            autoRegulationSummary = plan.summary + " 已执行：" + applied.joined(separator: "、")
        }
        return autoRegulationSummary
    }

    private func currentResourceFocus() -> VeilAppResourceFocus {
        switch computeGovernor.plan.focus {
        case .mediaTransfer: return .communications
        case .languageChat, .videoChat: return .agent
        case .gameDecision: return .game
        default: return .automatic
        }
    }

    private func currentControlDestination() -> VeilAppDestination {
        switch selectedSection {
        case .chats: return .chats
        case .nearby: return .nearby
        case .games: return .games
        case .agent: return .agent
        case .settings: return .settings
        }
    }

    private func currentAutoThermalLevel() -> VeilAutoThermalLevel {
        #if os(iOS)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
        #else
        return .nominal
        #endif
    }

    func setAgentAutoLoadLanguageModel(_ enabled: Bool) {
        agentControls.autoLoadLanguageModel = enabled
        if enabled { agent.activate() }
    }

    func setAgentConversationTextAccessEnabled(_ enabled: Bool) {
        agentControls.conversationTextAccessEnabled = enabled
    }

    func setAgentVisualContextEnabled(_ enabled: Bool) {
        agentControls.visualContextEnabled = enabled
        agent.setVisualContextEnabled(enabled)
    }

    func setAgentLocalToolMutationsEnabled(_ enabled: Bool) {
        agentControls.localToolMutationsEnabled = enabled
    }

    func setAgentSuggestedGameMoveExecutionEnabled(_ enabled: Bool) {
        agentControls.allowSuggestedGameMoveExecution = enabled
    }

    func setAgentGameDecisionMode(_ mode: AgentGameDecisionMode) {
        agentControls.gameDecisionMode = .baselineOnly
        computeGovernor.setExperimentalCoreEnabled(false)
        gameIntelligence.reconfigure()
        if mode != .baselineOnly {
            alertMessage = "Core 版已固定使用原生规则 Bot；神经游戏策略不再参与默认运行时。"
        }
        haptics.selection()
    }

    func trimAgentMemory() {
        agent.trimRuntimeMemory()
        ImagePreviewCache.shared.removeAll()
        refreshA9Health()
    }

    func resetAgentControls() {
        agentControls.resetToSafeDefaults()
        computeGovernor.setExperimentalCoreEnabled(false)
        agent.setVisualContextEnabled(agentControls.visualContextEnabled)
        gameIntelligence.reconfigure()
        haptics.resolved()
    }

    func agentDiagnosticsReport() -> String {
        [
            agent.diagnosticsReport(),
            "",
            "VeilLink AI Control Center",
            "Auto-load LLM: \(agentControls.autoLoadLanguageModel)",
            "Conversation text access: \(agentControls.conversationTextAccessEnabled)",
            "Visual context: \(agentControls.visualContextEnabled)",
            "Local tool mutations: \(agentControls.localToolMutationsEnabled)",
            "Suggested move execution: \(agentControls.allowSuggestedGameMoveExecution)",
            "Game decision mode: native-bot",
            "Neural game runtime: disabled in Core",
            "Privacy: no message plaintext, media, keys, pairing codes or database paths in this report."
        ].joined(separator: "\n")
    }

}
